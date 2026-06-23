import 'dart:convert';
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

enum _DragKind { none, draw, move, resize }

/// Drawing + viewport + persistence controller for the Sketch Board tool.
class SketchBoardState extends ChangeNotifier {
  static const String _settingsKey = 'config';
  static const String _backgroundKey = 'background';

  final SketchBoardDbHelper _db = SketchBoardDbHelper.instance;

  // ---- Scene ----
  final List<SketchElement> _elements = [];
  SketchElement? _draft;
  final SketchHistory _history = SketchHistory();

  // ---- Viewport (matches browser `viewport {x,y,scale}`) ----
  Offset _offset = Offset.zero;
  double _scale = 1.0;

  // ---- Tool + properties ----
  ToolMode _mode = ToolMode.freehand;
  String _strokeColor = SketchBoardColors.defaultStroke;
  String? _fillColor;
  double _strokeWidth = 4;
  double _fontSize = 24;
  final String _fontFamily = 'sans-serif';
  String _fontWeight = 'normal';
  String _fontStyle = 'normal';
  final BrushStyle _brushStyle = BrushStyle.normal;
  CanvasBackground _background = CanvasBackground.checkerboard;

  // ---- Selection / interaction ----
  String? _selectedId;
  _DragKind _drag = _DragKind.none;
  Offset _lastWorld = Offset.zero;
  ResizeHandle? _activeHandle;
  SketchElement? _resizeOriginal;
  Rect _resizeOrigBounds = Rect.zero;
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

  // ---- Image decode cache (for rendering embedded/synced images) ----
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
  CanvasBackground get background => _background;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  bool get isEmpty => _elements.isEmpty && _draft == null;
  bool get hasUnsavedChanges => _dirty;
  List<DrawingRecord> get saved => _saved;
  String? get selectedId => _selectedId;
  TextElement? get editingText => _editingText;
  SkPoint? get pendingTextPos => _pendingTextPos;

  SketchElement? get selectedElement {
    if (_selectedId == null) return null;
    for (final el in _elements) {
      if (el.id == _selectedId) return el;
    }
    return null;
  }

  ui.Image? imageFor(String data) => _imageCache[data];

  // ---- Coordinate transforms ----
  Offset screenToWorld(Offset s) =>
      Offset((s.dx - _offset.dx) / _scale, (s.dy - _offset.dy) / _scale);

  Offset worldToScreen(Offset w) =>
      Offset(w.dx * _scale + _offset.dx, w.dy * _scale + _offset.dy);

  ViewportState get viewportState =>
      ViewportState(x: _offset.dx, y: _offset.dy, scale: _scale);

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
    if (m != ToolMode.select) _selectedId = null;
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

  /// Applies [fn] to the selected element (if any), recording one undo step.
  void _mutateSelected(void Function(SketchElement e) fn) {
    final sel = selectedElement;
    if (sel == null) return;
    _history.push(_elements);
    fn(sel);
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

  /// Mouse-wheel / trackpad zoom around [focalScreen].
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
      SketchElement? hit;
      for (final el in _elements.reversed) {
        if (el is RawElement) continue;
        if (hitTestElement(el, world, padding: 8 / _scale)) {
          hit = el;
          break;
        }
      }
      _selectedId = hit?.id;
      notifyListeners();
    } else if (_mode == ToolMode.text) {
      _pendingTextPos = SkPoint.fromOffset(world);
      _editingText = null;
      onRequestText?.call();
    }
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
      // A second finger joined mid-stroke: abandon the draft and pan/zoom.
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

  // ---- Interaction (draw / select / move / resize) ----
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
    // 1) Resize handle of the current selection?
    final sel = selectedElement;
    if (sel != null) {
      final handle = _hitHandle(sel, screen);
      if (handle != null) {
        _history.push(_elements);
        _drag = _DragKind.resize;
        _activeHandle = handle;
        _resizeOriginal = sel.clone();
        _resizeOrigBounds = elementBounds(sel);
        return;
      }
    }
    // 2) Topmost element under the pointer?
    SketchElement? hit;
    for (final el in _elements.reversed) {
      if (el is RawElement) continue;
      if (hitTestElement(el, world, padding: 6 / _scale)) {
        hit = el;
        break;
      }
    }
    if (hit != null) {
      _selectedId = hit.id;
      _history.push(_elements);
      _drag = _DragKind.move;
    } else {
      _selectedId = null;
      _drag = _DragKind.none;
    }
  }

  ResizeHandle? _hitHandle(SketchElement el, Offset screen) {
    final b = elementBounds(el);
    if (b.width <= 0 && b.height <= 0) return null;
    const radius = 14.0;
    for (final entry in handlePositions(b).entries) {
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
        final sel = selectedElement;
        if (sel != null) {
          translateElement(
            sel,
            world.dx - _lastWorld.dx,
            world.dy - _lastWorld.dy,
          );
          _lastWorld = world;
          _dirty = true;
          notifyListeners();
        }
      case _DragKind.resize:
        _applyResize(world);
      case _DragKind.none:
        break;
    }
  }

  void _applyResize(Offset world) {
    final original = _resizeOriginal;
    final handle = _activeHandle;
    if (original == null || handle == null) return;
    final nb = _resizedBounds(_resizeOrigBounds, handle, world);
    final fresh = original.clone();
    resizeElement(fresh, _resizeOrigBounds, nb);
    final idx = _elements.indexWhere((e) => e.id == fresh.id);
    if (idx != -1) _elements[idx] = fresh;
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
        if (_mode != ToolMode.freehand) {
          _selectedId = null;
        }
        _dirty = true;
      }
    }
    _drag = _DragKind.none;
    _activeHandle = null;
    _resizeOriginal = null;
    notifyListeners();
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
        _selectedId = null;
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
        _selectedId = el.id;
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

  // ---- History / scene mutations ----
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
    if (_selectedId != null && selectedElement == null) _selectedId = null;
    _ensureImages();
  }

  void deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    _history.push(_elements);
    _elements.removeWhere((e) => e.id == id);
    _selectedId = null;
    _dirty = true;
    notifyListeners();
  }

  void clear() {
    if (_elements.isEmpty) return;
    _history.push(_elements);
    _elements.clear();
    _draft = null;
    _selectedId = null;
    _loadedShortId = null;
    _dirty = true;
    notifyListeners();
  }

  void newDrawing() {
    if (_elements.isNotEmpty) _history.push(_elements);
    _elements.clear();
    _draft = null;
    _selectedId = null;
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
    _selectedId = null;
    _dirty = false;
    notifyListeners();
  }

  Future<void> deleteSaved(String shortId) async {
    await _db.softDelete(shortId);
    if (_loadedShortId == shortId) _loadedShortId = null;
    await refreshSaved();
  }

  @override
  void dispose() {
    for (final img in _imageCache.values) {
      img.dispose();
    }
    _imageCache.clear();
    super.dispose();
  }
}
