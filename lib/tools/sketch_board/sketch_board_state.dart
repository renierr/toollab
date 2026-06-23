import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'geometry/element_bounds.dart';
import 'geometry/element_transforms.dart';
import 'geometry/sketch_export.dart';
import 'models/drawing_record.dart';
import 'models/sketch_element.dart';
import 'models/sketch_enums.dart';
import 'models/sketch_history.dart';
import 'sketch_board_colors.dart';
import 'sketch_board_db_helper.dart';

enum _DragKind { none, draw, move, resize, rotate, marquee }

/// Drawing + viewport + persistence controller for the Sketch Board tool.
class SketchBoardState extends ChangeNotifier {
  static const String _settingsKey = 'config';
  static const String _backgroundKey = 'background';

  /// Screen-space gap from the selection top edge to the rotation handle.
  static const double rotationHandleGap = 28;

  final SketchBoardDbHelper _db = SketchBoardDbHelper.instance;

  // ---- Scene ----
  final List<SketchElement> _elements = [];
  SketchElement? _draft;
  final SketchHistory _history = SketchHistory();

  // ---- Viewport ----
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  Size _viewSize = const Size(800, 600);

  // ---- Tool + properties ----
  ToolMode _mode = ToolMode.freehand;
  String _strokeColor = SketchBoardColors.defaultStroke;
  String? _fillColor;
  double _strokeWidth = 4;
  double _fontSize = 24;
  final String _fontFamily = 'sans-serif';
  String _fontWeight = 'normal';
  String _fontStyle = 'normal';
  BrushStyle _brushStyle = BrushStyle.normal;
  CanvasBackground _background = CanvasBackground.checkerboard;
  SelectionType _selectionType = SelectionType.box;

  // ---- Selection / interaction ----
  final Set<String> _selectedIds = {};
  _DragKind _drag = _DragKind.none;
  Offset _lastWorld = Offset.zero;
  ResizeHandle? _activeHandle;
  Map<String, SketchElement> _origClones = {};
  Rect _origUnion = Rect.zero;
  Offset _rotatePivot = Offset.zero;
  double _rotateStartAngle = 0;
  Offset? _marqueeStartW;
  Offset _marqueeCurW = Offset.zero;
  final List<Offset> _lassoW = [];
  bool _gestureIsCamera = false;
  double _baseScale = 1;
  Offset _baseOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  // ---- Text placement ----
  SkPoint? _pendingTextPos;
  TextElement? _editingText;
  VoidCallback? onRequestText;

  // ---- Persistence ----
  List<DrawingRecord> _saved = [];
  String? _loadedShortId;
  bool _dirty = false;

  // ---- Image decode cache ----
  final Map<String, ui.Image> _imageCache = {};
  final Set<String> _decoding = {};

  SketchBoardState() {
    _load();
  }

  // ---- Getters ----
  List<SketchElement> get elements => _elements;
  SketchElement? get draft => _draft;
  ToolMode get mode => _mode;
  Offset get offset => _offset;
  double get scale => _scale;
  String get strokeColor => _strokeColor;
  String? get fillColor => _fillColor;
  double get strokeWidth => _strokeWidth;
  double get fontSize => _fontSize;
  bool get fontBold => _fontWeight == 'bold';
  bool get fontItalic => _fontStyle == 'italic';
  BrushStyle get brushStyle => _brushStyle;
  CanvasBackground get background => _background;
  SelectionType get selectionType => _selectionType;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  bool get isEmpty => _elements.isEmpty && _draft == null;
  bool get hasUnsavedChanges => _dirty;
  List<DrawingRecord> get saved => _saved;
  TextElement? get editingText => _editingText;
  SkPoint? get pendingTextPos => _pendingTextPos;

  Set<String> get selectedIds => _selectedIds;
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectionCount => _selectedIds.length;
  bool get hasGroupSelected => selectedElements.any((e) => e is GroupElement);

  List<SketchElement> get selectedElements =>
      _elements.where((e) => _selectedIds.contains(e.id)).toList();

  /// The element when exactly one is selected (used to drive the properties bar).
  SketchElement? get selectedElement {
    if (_selectedIds.length != 1) return null;
    for (final el in _elements) {
      if (el.id == _selectedIds.first) return el;
    }
    return null;
  }

  Rect? get selectionBounds {
    Rect? acc;
    for (final e in selectedElements) {
      final b = elementBounds(e);
      acc = acc == null ? b : acc.expandToInclude(b);
    }
    return acc;
  }

  Rect? get marqueeRectWorld =>
      (_drag == _DragKind.marquee &&
          _selectionType == SelectionType.box &&
          _marqueeStartW != null)
      ? Rect.fromPoints(_marqueeStartW!, _marqueeCurW)
      : null;

  List<Offset> get lassoWorld =>
      (_drag == _DragKind.marquee && _selectionType == SelectionType.lasso)
      ? _lassoW
      : const [];

  ui.Image? imageFor(String data) => _imageCache[data];

  // ---- Coordinate transforms ----
  Offset screenToWorld(Offset s) =>
      Offset((s.dx - _offset.dx) / _scale, (s.dy - _offset.dy) / _scale);

  Offset worldToScreen(Offset w) =>
      Offset(w.dx * _scale + _offset.dx, w.dy * _scale + _offset.dy);

  ViewportState get viewportState =>
      ViewportState(x: _offset.dx, y: _offset.dy, scale: _scale);

  Size get viewSize => _viewSize;

  /// Reported by the painter so inserted images land in the visible centre.
  void setViewSize(Size s) => _viewSize = s;

  // ---- Settings load/persist ----
  Future<void> _load() async {
    final stored = await DatabaseService.instance.getSetting(
      SketchBoardTool.config.id,
      _settingsKey,
    );
    if (stored != null) {
      try {
        final j = Map<String, dynamic>.from(jsonDecode(stored) as Map);
        _strokeColor = j['strokeColor'] as String? ?? _strokeColor;
        _fillColor = j['fillColor'] as String?;
        _strokeWidth = (j['strokeWidth'] as num?)?.toDouble() ?? _strokeWidth;
        _fontSize = (j['fontSize'] as num?)?.toDouble() ?? _fontSize;
      } catch (_) {}
    }
    final bg = await DatabaseService.instance.getSetting(
      SketchBoardTool.config.id,
      _backgroundKey,
    );
    if (bg != null) _background = canvasBackgroundFromString(bg);
    await refreshSaved();
    notifyListeners();
  }

  Future<void> _persistDefaults() async {
    await DatabaseService.instance.setSetting(
      SketchBoardTool.config.id,
      _settingsKey,
      jsonEncode({
        'strokeColor': _strokeColor,
        'fillColor': _fillColor,
        'strokeWidth': _strokeWidth,
        'fontSize': _fontSize,
      }),
    );
  }

  // ---- Tool / properties ----
  void setMode(ToolMode m) {
    if (_mode == m) return;
    _mode = m;
    if (m != ToolMode.select) _selectedIds.clear();
    notifyListeners();
  }

  void setSelectionType(SelectionType t) {
    if (_selectionType == t) return;
    _selectionType = t;
    notifyListeners();
  }

  void setStrokeColor(String hex) {
    _strokeColor = hex;
    _mutateSelected((e) => e.color = hex);
    _persistDefaults();
    notifyListeners();
  }

  void setFillColor(String? hexOrTransparent) {
    final v = (hexOrTransparent == null || hexOrTransparent == 'transparent')
        ? null
        : hexOrTransparent;
    _fillColor = v;
    _mutateSelected((e) => e.fillColor = v);
    _persistDefaults();
    notifyListeners();
  }

  void setStrokeWidth(double w) {
    _strokeWidth = w;
    _mutateSelected((e) => e.width = w);
    _persistDefaults();
    notifyListeners();
  }

  void setFontSize(double s) {
    _fontSize = s;
    _mutateSelected((e) {
      if (e is TextElement) e.fontSize = s;
    });
    _persistDefaults();
    notifyListeners();
  }

  void setBrushStyle(BrushStyle b) {
    _brushStyle = b;
    _mutateSelected((e) => e.brushStyle = b.name);
    notifyListeners();
  }

  void toggleBold() {
    _fontWeight = _fontWeight == 'bold' ? 'normal' : 'bold';
    _mutateSelected((e) {
      if (e is TextElement) e.fontWeight = _fontWeight;
    });
    notifyListeners();
  }

  void toggleItalic() {
    _fontStyle = _fontStyle == 'italic' ? 'normal' : 'italic';
    _mutateSelected((e) {
      if (e is TextElement) e.fontStyle = _fontStyle;
    });
    notifyListeners();
  }

  /// Applies [fn] to every selected element, recording one undo step.
  void _mutateSelected(void Function(SketchElement e) fn) {
    final sel = selectedElements;
    if (sel.isEmpty) return;
    _history.push(_elements);
    for (final e in sel) {
      fn(e);
    }
    _dirty = true;
  }

  Future<void> setBackground(CanvasBackground bg) async {
    if (_background == bg) return;
    _background = bg;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      SketchBoardTool.config.id,
      _backgroundKey,
      bg.name,
    );
  }

  // ---- Camera (pan + zoom) ----
  void beginCamera(Offset focal) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _startFocal = focal;
  }

  void updateCamera(Offset focal, double gestureScale) {
    final newScale = (_baseScale * gestureScale).clamp(0.1, 8.0);
    final worldUnderStart = Offset(
      (_startFocal.dx - _baseOffset.dx) / _baseScale,
      (_startFocal.dy - _baseOffset.dy) / _baseScale,
    );
    _offset = focal - worldUnderStart * newScale;
    _scale = newScale;
    notifyListeners();
  }

  void zoomBy(double factor, Offset focalScreen) {
    final newScale = (_scale * factor).clamp(0.1, 8.0);
    final worldUnder = screenToWorld(focalScreen);
    _scale = newScale;
    _offset = focalScreen - worldUnder * newScale;
    notifyListeners();
  }

  void resetView() {
    _offset = Offset.zero;
    _scale = 1.0;
    notifyListeners();
  }

  /// Immediate tap (no drag): select in select-mode, place text in text-mode.
  void handleTap(Offset screen) {
    final world = screenToWorld(screen);
    if (_mode == ToolMode.select) {
      final hit = _topmostAt(world);
      _selectedIds
        ..clear()
        ..addAll(hit == null ? const [] : [hit.id]);
      notifyListeners();
    } else if (_mode == ToolMode.text) {
      _pendingTextPos = SkPoint.fromOffset(world);
      _editingText = null;
      onRequestText?.call();
    }
  }

  SketchElement? _topmostAt(Offset world) {
    for (final el in _elements.reversed) {
      if (el is RawElement) continue;
      if (hitTestElement(el, world, padding: 8 / _scale)) return el;
    }
    return null;
  }

  // ---- Gesture routing ----
  void gestureStart(Offset localFocal, int pointerCount) {
    if (_mode == ToolMode.pan || pointerCount >= 2) {
      _gestureIsCamera = true;
      beginCamera(localFocal);
      return;
    }
    _gestureIsCamera = false;
    _beginInteraction(screenToWorld(localFocal), localFocal);
  }

  void gestureUpdate(Offset localFocal, double gestureScale, int pointerCount) {
    if (!_gestureIsCamera && pointerCount >= 2) {
      _draft = null;
      _drag = _DragKind.none;
      _gestureIsCamera = true;
      beginCamera(localFocal);
      return;
    }
    if (_gestureIsCamera) {
      updateCamera(localFocal, gestureScale);
    } else {
      _updateInteraction(screenToWorld(localFocal));
    }
  }

  void gestureEnd() {
    if (!_gestureIsCamera) _endInteraction();
    _gestureIsCamera = false;
  }

  // ---- Interaction ----
  void _beginInteraction(Offset world, Offset screen) {
    _lastWorld = world;
    switch (_mode) {
      case ToolMode.select:
        _beginSelect(world, screen);
      case ToolMode.text:
        _drag = _DragKind.none;
      case ToolMode.freehand:
        _draft = FreehandElement(
          id: _db.generateUuid(),
          color: _strokeColor,
          width: _strokeWidth,
          brushStyle: _brushStyle.name,
          points: [SkPoint.fromOffset(world)],
        );
        _drag = _DragKind.draw;
      case ToolMode.image:
      case ToolMode.pan:
        _drag = _DragKind.none;
      default:
        _draft = ShapeElement(
          id: _db.generateUuid(),
          shapeType: _mode.wire,
          color: _strokeColor,
          fillColor: _shapeUsesFill(_mode) ? _fillColor : null,
          width: _strokeWidth,
          brushStyle: _brushStyle.name,
          start: SkPoint.fromOffset(world),
          end: SkPoint.fromOffset(world),
        );
        _drag = _DragKind.draw;
    }
    notifyListeners();
  }

  bool _shapeUsesFill(ToolMode m) => const {
    ToolMode.rect,
    ToolMode.ellipse,
    ToolMode.triangle,
    ToolMode.diamond,
    ToolMode.hexagon,
    ToolMode.speechBubble,
  }.contains(m);

  void _beginSelect(Offset world, Offset screen) {
    final bounds = selectionBounds;
    if (bounds != null && (bounds.width > 0 || bounds.height > 0)) {
      if (_hitRotation(bounds, screen)) {
        _history.push(_elements);
        _drag = _DragKind.rotate;
        _origUnion = bounds;
        _rotatePivot = bounds.center;
        _rotateStartAngle = math.atan2(
          world.dy - bounds.center.dy,
          world.dx - bounds.center.dx,
        );
        _snapshotClones();
        return;
      }
      final handle = _hitHandle(bounds, screen);
      if (handle != null) {
        _history.push(_elements);
        _drag = _DragKind.resize;
        _activeHandle = handle;
        _origUnion = bounds;
        _snapshotClones();
        return;
      }
    }

    final hit = _topmostAt(world);
    if (hit != null) {
      if (!_selectedIds.contains(hit.id)) {
        _selectedIds
          ..clear()
          ..add(hit.id);
      }
      _history.push(_elements);
      _drag = _DragKind.move;
    } else {
      _selectedIds.clear();
      _drag = _DragKind.marquee;
      if (_selectionType == SelectionType.box) {
        _marqueeStartW = world;
        _marqueeCurW = world;
      } else {
        _lassoW
          ..clear()
          ..add(world);
      }
    }
  }

  void _snapshotClones() {
    _origClones = {for (final e in selectedElements) e.id: e.clone()};
  }

  bool _hitRotation(Rect bounds, Offset screen) {
    final pos =
        worldToScreen(bounds.topCenter) - const Offset(0, rotationHandleGap);
    return (pos - screen).distance <= 14;
  }

  ResizeHandle? _hitHandle(Rect bounds, Offset screen) {
    const radius = 14.0;
    for (final entry in handlePositions(bounds).entries) {
      final sp = worldToScreen(entry.value);
      if ((sp - screen).distance <= radius) return entry.key;
    }
    return null;
  }

  void _updateInteraction(Offset world) {
    switch (_drag) {
      case _DragKind.draw:
        final d = _draft;
        if (d is FreehandElement) {
          final last = d.points.last;
          final min = 1.5 / _scale;
          if ((world.dx - last.x).abs() >= min ||
              (world.dy - last.y).abs() >= min) {
            d.points.add(SkPoint.fromOffset(world));
          }
        } else if (d is ShapeElement) {
          d.end = SkPoint.fromOffset(world);
        }
        notifyListeners();
      case _DragKind.move:
        for (final e in selectedElements) {
          translateElement(
            e,
            world.dx - _lastWorld.dx,
            world.dy - _lastWorld.dy,
          );
        }
        _lastWorld = world;
        _dirty = true;
        notifyListeners();
      case _DragKind.resize:
        _applyResize(world);
      case _DragKind.rotate:
        _applyRotate(world);
      case _DragKind.marquee:
        if (_selectionType == SelectionType.box) {
          _marqueeCurW = world;
        } else {
          _lassoW.add(world);
        }
        notifyListeners();
      case _DragKind.none:
        break;
    }
  }

  void _applyResize(Offset world) {
    final handle = _activeHandle;
    if (handle == null || _origClones.isEmpty) return;

    final hasImage = _origClones.values.any((e) => e is ImageElement);
    final isCorner =
        handle == ResizeHandle.tl ||
        handle == ResizeHandle.tr ||
        handle == ResizeHandle.br ||
        handle == ResizeHandle.bl;

    Rect nb;
    if (hasImage && isCorner) {
      final wFrom = _origUnion.width;
      final hFrom = _origUnion.height;
      if (wFrom == 0 || hFrom == 0) {
        nb = _resizedBounds(_origUnion, handle, world);
      } else {
        Offset fixedPoint;
        switch (handle) {
          case ResizeHandle.tl:
            fixedPoint = _origUnion.bottomRight;
          case ResizeHandle.tr:
            fixedPoint = _origUnion.bottomLeft;
          case ResizeHandle.br:
            fixedPoint = _origUnion.topLeft;
          case ResizeHandle.bl:
            fixedPoint = _origUnion.topRight;
          default:
            fixedPoint = _origUnion.center;
        }
        final scaleX = (world.dx - fixedPoint.dx).abs() / wFrom;
        final scaleY = (world.dy - fixedPoint.dy).abs() / hFrom;
        final scale = (scaleX + scaleY) / 2.0;
        final wNew = wFrom * scale;
        final hNew = hFrom * scale;
        final signX = (world.dx - fixedPoint.dx) >= 0 ? 1.0 : -1.0;
        final signY = (world.dy - fixedPoint.dy) >= 0 ? 1.0 : -1.0;
        final newCorner = Offset(
          fixedPoint.dx + signX * wNew,
          fixedPoint.dy + signY * hNew,
        );
        nb = Rect.fromPoints(fixedPoint, newCorner);
      }
    } else {
      nb = _resizedBounds(_origUnion, handle, world);
    }

    bool flipX = false;
    bool flipY = false;
    switch (handle) {
      case ResizeHandle.tl:
        flipX = world.dx > _origUnion.right;
        flipY = world.dy > _origUnion.bottom;
      case ResizeHandle.tr:
        flipX = world.dx < _origUnion.left;
        flipY = world.dy > _origUnion.bottom;
      case ResizeHandle.br:
        flipX = world.dx < _origUnion.left;
        flipY = world.dy < _origUnion.top;
      case ResizeHandle.bl:
        flipX = world.dx > _origUnion.right;
        flipY = world.dy < _origUnion.top;
      case ResizeHandle.t:
        flipY = world.dy > _origUnion.bottom;
      case ResizeHandle.b:
        flipY = world.dy < _origUnion.top;
      case ResizeHandle.l:
        flipX = world.dx > _origUnion.right;
      case ResizeHandle.r:
        flipX = world.dx < _origUnion.left;
    }

    _origClones.forEach((id, clone) {
      final fresh = clone.clone();
      resizeElement(fresh, _origUnion, nb, flipX: flipX, flipY: flipY);
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx != -1) _elements[idx] = fresh;
    });
    _dirty = true;
    notifyListeners();
  }

  void _applyRotate(Offset world) {
    if (_origClones.isEmpty) return;
    final angle = math.atan2(
      world.dy - _rotatePivot.dy,
      world.dx - _rotatePivot.dx,
    );
    final delta = angle - _rotateStartAngle;
    _origClones.forEach((id, clone) {
      final fresh = clone.clone();
      rotateElementAbout(fresh, _rotatePivot, delta);
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx != -1) _elements[idx] = fresh;
    });
    _dirty = true;
    notifyListeners();
  }

  Rect _resizedBounds(Rect o, ResizeHandle h, Offset w) {
    double l = o.left, t = o.top, r = o.right, b = o.bottom;
    switch (h) {
      case ResizeHandle.tl:
        l = w.dx;
        t = w.dy;
      case ResizeHandle.t:
        t = w.dy;
      case ResizeHandle.tr:
        r = w.dx;
        t = w.dy;
      case ResizeHandle.r:
        r = w.dx;
      case ResizeHandle.br:
        r = w.dx;
        b = w.dy;
      case ResizeHandle.b:
        b = w.dy;
      case ResizeHandle.bl:
        l = w.dx;
        b = w.dy;
      case ResizeHandle.l:
        l = w.dx;
    }
    const minSize = 4.0;
    if ((r - l).abs() < minSize) r = l + (r >= l ? minSize : -minSize);
    if ((b - t).abs() < minSize) b = t + (b >= t ? minSize : -minSize);
    return Rect.fromLTRB(
      l < r ? l : r,
      t < b ? t : b,
      l < r ? r : l,
      t < b ? b : t,
    );
  }

  void _endInteraction() {
    if (_drag == _DragKind.draw) {
      final d = _draft;
      _draft = null;
      if (d != null && _isDraftValid(d)) {
        _history.push(_elements);
        _elements.add(d);
        _dirty = true;
      }
    } else if (_drag == _DragKind.marquee) {
      _finishMarquee();
    }
    _drag = _DragKind.none;
    _activeHandle = null;
    _origClones = {};
    _marqueeStartW = null;
    _lassoW.clear();
    notifyListeners();
  }

  void _finishMarquee() {
    if (_selectionType == SelectionType.box && _marqueeStartW != null) {
      final rect = Rect.fromPoints(_marqueeStartW!, _marqueeCurW);
      if (rect.width < 2 && rect.height < 2) return;
      _selectedIds
        ..clear()
        ..addAll(
          _elements
              .where((e) => e is! RawElement && elementBounds(e).overlaps(rect))
              .map((e) => e.id),
        );
    } else if (_selectionType == SelectionType.lasso && _lassoW.length > 2) {
      _selectedIds
        ..clear()
        ..addAll(
          _elements
              .where(
                (e) =>
                    e is! RawElement &&
                    _pointInPolygon(elementBounds(e).center, _lassoW),
              )
              .map((e) => e.id),
        );
    }
  }

  bool _pointInPolygon(Offset p, List<Offset> poly) {
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if (((a.dy > p.dy) != (b.dy > p.dy)) &&
          (p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  bool _isDraftValid(SketchElement d) {
    if (d is FreehandElement) return d.points.length > 1;
    if (d is ShapeElement) {
      final dx = (d.end.x - d.start.x).abs();
      final dy = (d.end.y - d.start.y).abs();
      return dx >= 2 || dy >= 2;
    }
    return true;
  }

  // ---- Text ----
  void commitText(String text) {
    final pos = _pendingTextPos;
    final editing = _editingText;
    if (editing != null) {
      _history.push(_elements);
      if (text.trim().isEmpty) {
        _elements.removeWhere((e) => e.id == editing.id);
        _selectedIds.clear();
      } else {
        editing.text = text;
      }
      _dirty = true;
    } else if (pos != null && text.trim().isNotEmpty) {
      _history.push(_elements);
      _elements.add(
        TextElement(
          id: _db.generateUuid(),
          color: _strokeColor,
          width: _strokeWidth,
          position: pos,
          text: text,
          fontFamily: _fontFamily,
          fontSize: _fontSize,
          fontWeight: _fontWeight,
          fontStyle: _fontStyle,
        ),
      );
      _dirty = true;
    }
    _pendingTextPos = null;
    _editingText = null;
    notifyListeners();
  }

  void cancelText() {
    _pendingTextPos = null;
    _editingText = null;
    notifyListeners();
  }

  void doubleTapAt(Offset screen) {
    final world = screenToWorld(screen);
    for (final el in _elements.reversed) {
      if (el is TextElement && hitTestElement(el, world, padding: 6 / _scale)) {
        _selectedIds
          ..clear()
          ..add(el.id);
        editSelectedText();
        return;
      }
    }
  }

  bool editSelectedText() {
    final sel = selectedElement;
    if (sel is TextElement) {
      _editingText = sel;
      _pendingTextPos = sel.position;
      onRequestText?.call();
      return true;
    }
    return false;
  }

  // ---- Selection ops: z-order, group, image, delete ----
  void bringToFront() {
    if (_selectedIds.isEmpty) return;
    _history.push(_elements);
    final sel = _elements.where((e) => _selectedIds.contains(e.id)).toList();
    _elements.removeWhere((e) => _selectedIds.contains(e.id));
    _elements.addAll(sel);
    _dirty = true;
    notifyListeners();
  }

  void sendToBack() {
    if (_selectedIds.isEmpty) return;
    _history.push(_elements);
    final sel = _elements.where((e) => _selectedIds.contains(e.id)).toList();
    _elements.removeWhere((e) => _selectedIds.contains(e.id));
    _elements.insertAll(0, sel);
    _dirty = true;
    notifyListeners();
  }

  void groupSelected() {
    if (_selectedIds.length < 2) return;
    final sel = _elements.where((e) => _selectedIds.contains(e.id)).toList();
    _history.push(_elements);
    final group = GroupElement(
      id: _db.generateUuid(),
      color: sel.first.color,
      fillColor: sel.first.fillColor,
      width: sel.first.width,
      brushStyle: sel.first.brushStyle,
      elements: sel.map((e) => e.clone()).toList(),
    );
    final firstIdx = _elements.indexWhere((e) => _selectedIds.contains(e.id));
    _elements.removeWhere((e) => _selectedIds.contains(e.id));
    _elements.insert(firstIdx.clamp(0, _elements.length), group);
    _selectedIds
      ..clear()
      ..add(group.id);
    _dirty = true;
    notifyListeners();
  }

  void ungroupSelected() {
    final groups = selectedElements.whereType<GroupElement>().toList();
    if (groups.isEmpty) return;
    _history.push(_elements);
    final newSel = <String>{};
    for (final g in groups) {
      final idx = _elements.indexOf(g);
      if (idx == -1) continue;
      final children = g.elements.map((c) => c.clone()).toList();
      if (g.rotation != 0) {
        final pivot = elementBounds(g).center;
        for (final c in children) {
          rotateElementAbout(c, pivot, g.rotation);
        }
      }
      _elements.removeAt(idx);
      _elements.insertAll(idx, children);
      newSel.addAll(children.map((c) => c.id));
    }
    _selectedIds
      ..clear()
      ..addAll(newSel);
    _ensureImages();
    _dirty = true;
    notifyListeners();
  }

  Future<void> addImage(Uint8List bytes, {String mime = 'image/png'}) async {
    ui.Image img;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      img = (await codec.getNextFrame()).image;
    } catch (_) {
      return;
    }
    final w0 = img.width.toDouble(), h0 = img.height.toDouble();
    final w = w0, h = h0;
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    _imageCache[dataUrl] = img;

    final isFirst = _elements.isEmpty;
    final center = screenToWorld(
      Offset(_viewSize.width / 2, _viewSize.height / 2),
    );
    final el = ImageElement(
      id: _db.generateUuid(),
      color: '#000000',
      width: 1,
      position: SkPoint(center.dx - w / 2, center.dy - h / 2),
      imageWidth: w,
      imageHeight: h,
      imageData: dataUrl,
      originalWidth: w0,
      originalHeight: h0,
    );
    _history.push(_elements);
    _elements.add(el);

    if (isFirst && _viewSize.width > 0 && _viewSize.height > 0) {
      final scaleFit =
          math.min(_viewSize.width / w, _viewSize.height / h) * 0.9;
      _scale = math.min(1.0, scaleFit).clamp(0.1, 8.0);
      _offset = Offset(
        _viewSize.width / 2 - center.dx * _scale,
        _viewSize.height / 2 - center.dy * _scale,
      );
    }

    _mode = ToolMode.select;
    _selectedIds
      ..clear()
      ..add(el.id);
    _dirty = true;
    notifyListeners();
  }

  void deleteSelected() {
    if (_selectedIds.isEmpty) return;
    _history.push(_elements);
    _elements.removeWhere((e) => _selectedIds.contains(e.id));
    _selectedIds.clear();
    _dirty = true;
    notifyListeners();
  }

  void resetImageSize() {
    final sel = selectedElement;
    if (sel is ImageElement &&
        sel.originalWidth != null &&
        sel.originalHeight != null) {
      _history.push(_elements);
      final idx = _elements.indexWhere((e) => e.id == sel.id);
      if (idx != -1) {
        final fresh = sel.clone();
        fresh.imageWidth = sel.originalWidth!;
        fresh.imageHeight = sel.originalHeight!;
        _elements[idx] = fresh;
        _dirty = true;
        notifyListeners();
      }
    }
  }

  // ---- History ----
  void undo() {
    final prev = _history.undo(_elements);
    if (prev == null) return;
    _setElements(prev);
    _dirty = true;
    notifyListeners();
  }

  void redo() {
    final next = _history.redo(_elements);
    if (next == null) return;
    _setElements(next);
    _dirty = true;
    notifyListeners();
  }

  void _setElements(List<SketchElement> next) {
    _elements
      ..clear()
      ..addAll(next);
    _selectedIds.removeWhere((id) => !_elements.any((e) => e.id == id));
    _ensureImages();
  }

  void clear() {
    if (_elements.isEmpty) return;
    _history.push(_elements);
    _elements.clear();
    _draft = null;
    _selectedIds.clear();
    _loadedShortId = null;
    _dirty = true;
    notifyListeners();
  }

  void newDrawing() {
    if (_elements.isNotEmpty) _history.push(_elements);
    _elements.clear();
    _draft = null;
    _selectedIds.clear();
    _loadedShortId = null;
    _dirty = false;
    resetView();
  }

  // ---- Embedded image decoding ----
  void _ensureImages() {
    void walk(List<SketchElement> els) {
      for (final el in els) {
        if (el is ImageElement &&
            el.imageData.isNotEmpty &&
            !_imageCache.containsKey(el.imageData) &&
            !_decoding.contains(el.imageData)) {
          _decoding.add(el.imageData);
          final key = el.imageData;
          decodeImageData(key).then((img) {
            _decoding.remove(key);
            if (img != null) {
              _imageCache[key] = img;
              notifyListeners();
            }
          });
        } else if (el is GroupElement) {
          walk(el.elements);
        }
      }
    }

    walk(_elements);
  }

  // ---- Persistence ----
  Future<void> refreshSaved() async {
    _saved = await _db.getActiveRecords();
    notifyListeners();
  }

  Future<bool> save(String name) async {
    if (_elements.isEmpty) return false;
    final thumb = await makeThumbnail(_elements);
    final stats = summarize(_elements);
    final meta = DrawingMeta(
      elementCount: stats.count,
      colors: stats.colors,
      lastTool: _mode.wire,
      background: _background.name,
    );
    final shortId = _loadedShortId ?? _db.generateUuid();
    await _db.saveRecord(
      shortId: shortId,
      name: name,
      viewport: viewportState,
      elements: _elements,
      thumbnail: thumb,
      meta: meta,
    );
    _loadedShortId = shortId;
    _dirty = false;
    await refreshSaved();
    notifyListeners();
    return true;
  }

  void loadRecord(DrawingRecord record) {
    _setElements(record.elements.map((e) => e.clone()).toList());
    _history.clear();
    _offset = Offset(record.viewport.x, record.viewport.y);
    _scale = record.viewport.scale == 0 ? 1.0 : record.viewport.scale;
    _loadedShortId = record.shortId;
    _selectedIds.clear();
    _dirty = false;
    notifyListeners();
  }

  Future<void> deleteSaved(String shortId) async {
    await _db.softDelete(shortId);
    if (_loadedShortId == shortId) _loadedShortId = null;
    await refreshSaved();
  }

  void discardChanges() {
    _dirty = false;
    notifyListeners();
  }

  void clearMemory({bool notify = true}) {
    _elements.clear();
    _draft = null;
    _selectedIds.clear();
    _loadedShortId = null;
    _dirty = false;
    _history.clear();
    for (final img in _imageCache.values) {
      img.dispose();
    }
    _imageCache.clear();
    _decoding.clear();
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    clearMemory(notify: false);
    super.dispose();
  }
}
