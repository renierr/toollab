import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/unit_model.dart';
import 'unit_catalog.dart';
import 'unit_format.dart';

/// Holds the active category, selected units and input value for the unit
/// converter, persisting the last selection via [DatabaseService].
class UnitConverterState extends ChangeNotifier {
  static const _keyCategory = 'category';
  static const _keyFrom = 'from_unit';
  static const _keyTo = 'to_unit';

  final String _toolId = UnitConverterTool.config.id;

  late UnitCategory _category = UnitCatalog.categories.first;
  late UnitDef _from = _category.units.first;
  late UnitDef _to = _category.units[1];
  String _input = '1';

  /// Bumped whenever the input is changed programmatically (swap), so the text
  /// field can resync its controller without fighting user typing.
  int _inputRevision = 0;

  UnitConverterState() {
    _restore();
  }

  UnitCategory get category => _category;
  UnitDef get fromUnit => _from;
  UnitDef get toUnit => _to;
  String get input => _input;
  int get inputRevision => _inputRevision;

  /// The converted result, or `null` when the input is empty/invalid.
  double? get result {
    final value = parseUnitInput(_input);
    if (value == null) return null;
    return _category.convert(value, _from, _to);
  }

  /// Converts the current input into every unit of the active category.
  /// Returns an empty map when the input is invalid.
  Map<String, double> get allConversions {
    final value = parseUnitInput(_input);
    if (value == null) return const {};
    return {
      for (final u in _category.units) u.id: _category.convert(value, _from, u),
    };
  }

  void selectCategory(String id) {
    if (id == _category.id) return;
    final next = UnitCatalog.categoryById(id);
    if (next == null) return;
    _category = next;
    _from = next.units.first;
    _to = next.units.length > 1 ? next.units[1] : next.units.first;
    _persist();
    notifyListeners();
  }

  void setFrom(UnitDef unit) {
    if (unit.id == _from.id) return;
    _from = unit;
    _persist();
    notifyListeners();
  }

  void setTo(UnitDef unit) {
    if (unit.id == _to.id) return;
    _to = unit;
    _persist();
    notifyListeners();
  }

  /// Sets the input from user typing — does not bump the revision so the text
  /// field controller is left untouched.
  void setInput(String value) {
    if (value == _input) return;
    _input = value;
    notifyListeners();
  }

  /// Swaps the from/to units and moves the current result into the input.
  void swap() {
    final previousResult = result;
    final tmp = _from;
    _from = _to;
    _to = tmp;
    if (previousResult != null && previousResult.isFinite) {
      _input = formatUnitValue(previousResult);
      _inputRevision++;
    }
    _persist();
    notifyListeners();
  }

  Future<void> _restore() async {
    try {
      final db = DatabaseService.instance;
      final settings = await db.getAllSettings(_toolId);
      final category = UnitCatalog.categoryById(settings[_keyCategory] ?? '');
      if (category != null) {
        _category = category;
        _from = category.unitById(settings[_keyFrom] ?? '') ?? category.units.first;
        _to =
            category.unitById(settings[_keyTo] ?? '') ??
            (category.units.length > 1
                ? category.units[1]
                : category.units.first);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('UnitConverterState: failed to restore settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final db = DatabaseService.instance;
      await db.setSetting(_toolId, _keyCategory, _category.id);
      await db.setSetting(_toolId, _keyFrom, _from.id);
      await db.setSetting(_toolId, _keyTo, _to.id);
    } catch (e) {
      debugPrint('UnitConverterState: failed to persist settings: $e');
    }
  }
}
