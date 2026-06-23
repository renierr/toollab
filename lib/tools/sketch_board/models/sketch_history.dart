import 'sketch_element.dart';

/// Snapshot-based undo/redo for the element list.
///
/// Each entry is a deep clone of the full scene at a point in time. Ported from
/// the browser-toolkit `HistoryManager`: push on every committed mutation, then
/// [undo]/[redo] swap the live list for an adjacent snapshot.
class SketchHistory {
  static const int _maxDepth = 100;

  final List<List<SketchElement>> _undo = [];
  final List<List<SketchElement>> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  List<SketchElement> _snapshot(List<SketchElement> els) =>
      els.map((e) => e.clone()).toList();

  /// Records [current] as the latest snapshot, clearing the redo stack.
  void push(List<SketchElement> current) {
    _undo.add(_snapshot(current));
    if (_undo.length > _maxDepth) _undo.removeAt(0);
    _redo.clear();
  }

  /// Returns the previous snapshot, or null if there is nothing to undo.
  /// [current] is pushed onto the redo stack.
  List<SketchElement>? undo(List<SketchElement> current) {
    if (_undo.isEmpty) return null;
    _redo.add(_snapshot(current));
    return _undo.removeLast();
  }

  /// Returns the next snapshot, or null if there is nothing to redo.
  List<SketchElement>? redo(List<SketchElement> current) {
    if (_redo.isEmpty) return null;
    _undo.add(_snapshot(current));
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
