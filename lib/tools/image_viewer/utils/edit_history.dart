import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/tools/image_viewer/utils/image_editor_tasks.dart';

/// A single undo/redo step.
///
/// [apply] reproduces the state *after* the edit from the state *before* it
/// (redo); [revert] reproduces the state *before* from the state *after* (undo).
///
/// Reversible edits (rotate, flip) reconstruct both directions from their op
/// params and hold no pixel data. Destructive edits (crop, redact, resize)
/// cannot be inverted mathematically, so they keep the pre-edit image as a
/// compressed PNG snapshot and decode it on undo.
abstract class EditStep {
  Future<img.Image> apply(img.Image before);
  Future<img.Image> revert(img.Image after);
}

class RotateStep extends EditStep {
  final int angle;
  RotateStep(this.angle);

  @override
  Future<img.Image> apply(img.Image before) =>
      compute(rotateImageTask, RotateParams(before, angle));

  @override
  Future<img.Image> revert(img.Image after) =>
      compute(rotateImageTask, RotateParams(after, (360 - angle) % 360));
}

class FlipStep extends EditStep {
  final String direction;
  FlipStep(this.direction);

  // Flipping along the same axis is its own inverse.
  @override
  Future<img.Image> apply(img.Image before) =>
      compute(flipImageTask, FlipParams(before, direction));

  @override
  Future<img.Image> revert(img.Image after) =>
      compute(flipImageTask, FlipParams(after, direction));
}

/// Base for edits that destroy pixel data and must snapshot the pre-edit image.
abstract class _SnapshotStep extends EditStep {
  final Uint8List beforePng;
  _SnapshotStep(this.beforePng);

  @override
  Future<img.Image> revert(img.Image after) =>
      compute(decodeImageTask, beforePng);
}

class CropStep extends _SnapshotStep {
  final int x, y, width, height;
  CropStep(
    super.beforePng, {
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  Future<img.Image> apply(img.Image before) => compute(
    cropImageTask,
    CropParams(image: before, x: x, y: y, width: width, height: height),
  );
}

class ResizeStep extends _SnapshotStep {
  final int width, height;
  ResizeStep(super.beforePng, {required this.width, required this.height});

  @override
  Future<img.Image> apply(img.Image before) => compute(
    resizeImageTask,
    ResizeParams(image: before, width: width, height: height),
  );
}

class RedactStep extends _SnapshotStep {
  final int x, y, width, height;
  final String redactType;
  final double intensity;
  final int? colorValue;
  final List<double>? pathPoints;
  RedactStep(
    super.beforePng, {
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.redactType,
    required this.intensity,
    this.colorValue,
    this.pathPoints,
  });

  @override
  Future<img.Image> apply(img.Image before) => compute(
    redactImageTask,
    RedactParams(
      image: before,
      x: x,
      y: y,
      width: width,
      height: height,
      redactType: redactType,
      intensity: intensity,
      colorValue: colorValue,
      pathPoints: pathPoints,
    ),
  );
}

class SegmentStep extends _SnapshotStep {
  final Uint8List afterPng;
  SegmentStep(super.beforePng, this.afterPng);

  @override
  Future<img.Image> apply(img.Image before) =>
      compute(decodeImageTask, afterPng);
}

/// Bounded undo/redo stack.
///
/// Holds at most [maxSteps] edits. The current image is owned by the caller —
/// this class only stores how to move between states, so memory is one
/// uncompressed live image plus the PNG snapshots of any destructive edits
/// inside the window.
class EditHistory {
  static const int maxSteps = 5;

  final List<EditStep> _steps = [];
  // Number of edits currently applied; the live image is the state after this
  // many steps. Always within 0.._steps.length.
  int _cursor = 0;

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _steps.length;

  EditStep? get _undoStep => canUndo ? _steps[_cursor - 1] : null;
  EditStep? get _redoStep => canRedo ? _steps[_cursor] : null;

  void clear() {
    _steps.clear();
    _cursor = 0;
  }

  void record(EditStep step) {
    if (_cursor < _steps.length) {
      _steps.removeRange(_cursor, _steps.length);
    }
    _steps.add(step);
    if (_steps.length > maxSteps) {
      _steps.removeAt(0);
    }
    _cursor = _steps.length;
  }

  /// Reverts [current] one step. Returns the previous image, or null if there
  /// is nothing to undo. Advances the cursor only on success.
  Future<img.Image?> undo(img.Image current) async {
    final step = _undoStep;
    if (step == null) return null;
    final prev = await step.revert(current);
    _cursor--;
    return prev;
  }

  /// Re-applies the next step to [current]. Returns the next image, or null if
  /// there is nothing to redo. Advances the cursor only on success.
  Future<img.Image?> redo(img.Image current) async {
    final step = _redoStep;
    if (step == null) return null;
    final next = await step.apply(current);
    _cursor++;
    return next;
  }
}
