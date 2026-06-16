import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../signature_models.dart';
import 'package:tool_lab/widgets/checkerboard_background.dart';

import '../signature_painter.dart';
import '../signatures_state.dart';

/// The interactive drawing surface. Captures pointer input (with pressure)
/// and renders the live signature via [SignaturePainter].
class SignatureCanvas extends StatelessWidget {
  const SignatureCanvas({super.key});

  double _pressure(PointerEvent e) {
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return 1.0;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<SignaturesState>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final view = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) =>
                state.startStroke(e.localPosition, _pressure(e), view),
            onPointerMove: (e) =>
                state.extendStroke(e.localPosition, _pressure(e), view),
            onPointerUp: (_) => state.endStroke(),
            onPointerCancel: (_) => state.endStroke(),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Consumer<SignaturesState>(
                      builder: (context, s, _) => switch (s.background) {
                        CanvasBackground.checkerboard =>
                          const CheckerboardBackground(),
                        CanvasBackground.black => const ColoredBox(
                          color: Colors.black,
                        ),
                        CanvasBackground.white => const ColoredBox(
                          color: Colors.white,
                        ),
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: SignaturePainter(
                          repaintListenable: state,
                          pathsGetter: () => state.paths,
                          currentGetter: () => state.currentStroke,
                          settingsGetter: () => state.settings,
                          transformGetter: state.fitTransform,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Consumer<SignaturesState>(
                        builder: (context, s, _) {
                          if (!s.isEmpty) return const SizedBox.shrink();
                          return Center(
                            child: Text(
                              'Sign here',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
