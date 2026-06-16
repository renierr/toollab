import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'signature_export.dart';
import 'signature_geometry.dart';
import 'signature_models.dart';
import 'signature_painter.dart';
import 'signatures_db_helper.dart';

/// Drawing + persistence controller for the Signature Creator tool.
class SignaturesState extends ChangeNotifier {
  static const String _settingsKey = 'config';

  final SignaturesDbHelper _db = SignaturesDbHelper.instance;
  final Stopwatch _clock = Stopwatch()..start();

  final List<List<SignaturePoint>> _paths = [];
  final List<SignaturePoint> _current = [];
  final List<SignatureCmd> _undo = [];
  final List<SignatureCmd> _redo = [];

  SignatureSettings _settings = SignatureSettings.defaults;
  String? _lastLoadedId;
  Size _canvasSize = const Size(300, 150);

  List<SignatureRecord> _saved = [];
  bool _isDrawing = false;

  SignaturesState() {
    _load();
  }

  // ---- Getters ----
  List<List<SignaturePoint>> get paths => _paths;
  List<SignaturePoint> get currentStroke => _current;
  SignatureSettings get settings => _settings;
  List<SignatureRecord> get saved => _saved;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isEmpty => _paths.isEmpty && _current.isEmpty;
  Size get canvasSize => _canvasSize;

  Future<void> _load() async {
    final stored = await DatabaseService.instance.getSetting(
      SignaturesTool.config.id,
      _settingsKey,
    );
    if (stored != null) {
      try {
        _settings = SignatureSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(stored) as Map),
        );
      } catch (_) {}
    }
    await refreshSaved();
    notifyListeners();
  }

  void setCanvasSize(Size size) {
    if (size.width > 0 && size.height > 0) _canvasSize = size;
  }

  // ---- Settings ----
  Future<void> updateSettings(SignatureSettings next) async {
    _settings = next;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      SignaturesTool.config.id,
      _settingsKey,
      jsonEncode(next.toJson()),
    );
  }

  Future<void> resetSettings() => updateSettings(SignatureSettings.defaults);

  double get _now => _clock.elapsedMicroseconds / 1000.0;

  // ---- Drawing ----
  void startStroke(Offset pos, double pressure) {
    _isDrawing = true;
    _current
      ..clear()
      ..add(
        SignaturePoint(
          x: pos.dx,
          y: pos.dy,
          timestamp: _now,
          pressure: pressure,
        ),
      );
    notifyListeners();
  }

  void extendStroke(Offset pos, double pressure) {
    if (!_isDrawing) return;
    if (_current.isNotEmpty) {
      final prev = _current.last;
      final dx = pos.dx - prev.x;
      final dy = pos.dy - prev.y;
      final tol = _settings.moveTolerance;
      if (dx * dx + dy * dy < tol * tol) return;
    }
    _current.add(
      SignaturePoint(x: pos.dx, y: pos.dy, timestamp: _now, pressure: pressure),
    );
    notifyListeners();
  }

  void endStroke() {
    if (!_isDrawing) return;
    _isDrawing = false;
    if (_current.isEmpty) return;

    final simplified = simplifyRdp(
      List<SignaturePoint>.from(_current),
      rdpEpsilon(_settings.rdpMode),
    );
    _current.clear();
    _paths.add(simplified);
    _undo.add(AddPathCmd(List<SignaturePoint>.from(simplified)));
    _redo.clear();
    notifyListeners();
  }

  void clear() {
    if (_paths.isEmpty) return;
    _undo.add(ClearCmd(_clonePaths(_paths)));
    _redo.clear();
    _paths.clear();
    _current.clear();
    _lastLoadedId = null;
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final cmd = _undo.removeLast();
    switch (cmd) {
      case AddPathCmd _:
        if (_paths.isNotEmpty) _paths.removeLast();
      case ClearCmd c:
        _setPaths(c.prev);
      case ReplaceCmd c:
        _setPaths(c.prev);
    }
    _redo.add(cmd);
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final cmd = _redo.removeLast();
    switch (cmd) {
      case AddPathCmd c:
        _paths.add(List<SignaturePoint>.from(c.path));
      case ClearCmd _:
        _paths.clear();
      case ReplaceCmd c:
        _setPaths(c.next);
    }
    _undo.add(cmd);
    notifyListeners();
  }

  void _setPaths(List<List<SignaturePoint>> next) {
    _paths
      ..clear()
      ..addAll(_clonePaths(next));
  }

  List<List<SignaturePoint>> _clonePaths(List<List<SignaturePoint>> src) =>
      src.map((s) => List<SignaturePoint>.from(s)).toList();

  // ---- Export helpers (operate on the current canvas) ----
  NormalizedSignature _normalizedCurrent() =>
      normalizeSignature(_paths, _settings.penWidth);

  Future<Uint8List?> exportCurrentPng() async {
    if (_paths.isEmpty) return null;
    final norm = _normalizedCurrent();
    return renderSignaturePng(norm.paths, norm.width, norm.height, _settings);
  }

  String? exportCurrentSvg() {
    if (_paths.isEmpty) return null;
    final norm = _normalizedCurrent();
    return generateSignatureSvg(norm.paths, norm.width, norm.height, _settings);
  }

  // ---- Persistence ----
  Future<void> refreshSaved() async {
    _saved = await _db.getActiveRecords();
    notifyListeners();
  }

  /// Saves the current canvas as a new (or updated) signature record.
  Future<bool> save() async {
    if (_paths.isEmpty) return false;
    final norm = _normalizedCurrent();
    final preview = await renderSignaturePng(
      norm.paths,
      norm.width,
      norm.height,
      _settings.copyWith(dpi: 96),
    );
    final shortId = _lastLoadedId ?? _db.generateUuid();
    await _db.saveRecord(
      shortId: shortId,
      image: preview,
      width: norm.width,
      height: norm.height,
      rawPaths: norm.paths,
      settings: _settings,
    );
    _lastLoadedId = null;
    _paths.clear();
    _current.clear();
    _undo.clear();
    _redo.clear();
    await refreshSaved();
    notifyListeners();
    return true;
  }

  Future<void> deleteSaved(String shortId) async {
    await _db.softDelete(shortId);
    await refreshSaved();
  }

  /// Loads a saved signature back onto the canvas, scaled and centered.
  void loadRecord(SignatureRecord record) {
    final prev = _clonePaths(_paths);
    final scale = [
      _canvasSize.width / record.width,
      _canvasSize.height / record.height,
      1.0,
    ].reduce((a, b) => a < b ? a : b);
    final offsetX = (_canvasSize.width - record.width * scale) / 2;
    final offsetY = (_canvasSize.height - record.height * scale) / 2;

    final scaled = record.rawPaths
        .map(
          (stroke) => stroke
              .map(
                (p) => p.copyWith(
                  x: p.x * scale + offsetX,
                  y: p.y * scale + offsetY,
                ),
              )
              .toList(),
        )
        .toList();

    _undo.add(ReplaceCmd(prev, _clonePaths(scaled)));
    _redo.clear();
    _setPaths(scaled);
    _settings = record.settings;
    _lastLoadedId = record.shortId;
    notifyListeners();
  }
}
