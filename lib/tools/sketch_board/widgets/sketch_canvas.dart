import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/checkerboard_background.dart';

import '../models/sketch_enums.dart';
import '../sketch_board_colors.dart';
import '../sketch_board_state.dart';
import 'sketch_painter.dart';

class SketchCanvas extends StatelessWidget {
  const SketchCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<SketchBoardState>();
    final accent = Theme.of(context).colorScheme.primary;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final factor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
          state.zoomBy(factor, event.localPosition);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) =>
            state.gestureStart(d.localFocalPoint, d.pointerCount),
        onScaleUpdate: (d) =>
            state.gestureUpdate(d.localFocalPoint, d.scale, d.pointerCount),
        onScaleEnd: (_) => state.gestureEnd(),
        onTapUp: (d) => state.handleTap(d.localPosition),
        onDoubleTapDown: (d) => state.doubleTapAt(d.localPosition),
        onDoubleTap: () {},
        child: _CursorRegion(
          child: Stack(
            children: [
              const Positioned.fill(child: _Background()),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: SketchPainter(state: state, handleColor: accent),
                  ),
                ),
              ),
              const Positioned.fill(child: _EmptyHint()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Selector<SketchBoardState, CanvasBackground>(
      selector: (_, s) => s.background,
      builder: (context, bg, _) {
        switch (bg) {
          case CanvasBackground.white:
            return const ColoredBox(color: Colors.white);
          case CanvasBackground.black:
            return ColoredBox(color: SketchBoardColors.canvasBlack);
          case CanvasBackground.checkerboard:
            return const CheckerboardBackground();
        }
      },
    );
  }
}

class _CursorRegion extends StatelessWidget {
  final Widget child;
  const _CursorRegion({required this.child});

  @override
  Widget build(BuildContext context) {
    return Selector<SketchBoardState, ToolMode>(
      selector: (_, s) => s.mode,
      builder: (context, mode, _) {
        final cursor = switch (mode) {
          ToolMode.pan => SystemMouseCursors.grab,
          ToolMode.select => SystemMouseCursors.basic,
          ToolMode.text => SystemMouseCursors.text,
          _ => SystemMouseCursors.precise,
        };
        return MouseRegion(cursor: cursor, child: child);
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<SketchBoardState, bool>(
      selector: (_, s) => s.isEmpty,
      builder: (context, empty, _) {
        if (!empty) return const SizedBox.shrink();
        return IgnorePointer(
          child: Center(
            child: Text(
              AppLocalizations.of(context).sketchEmptyHint,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}
