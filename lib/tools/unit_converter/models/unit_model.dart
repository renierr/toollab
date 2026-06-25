import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Resolves a localized display string from [AppLocalizations].
typedef UnitL10n = String Function(AppLocalizations l10n);

/// A single unit within a [UnitCategory].
///
/// Linear units convert via [factor] (`value * factor = base value`). Units with
/// an affine or inverse relationship to the base (temperature, fuel economy)
/// provide explicit [toBase] / [fromBase] functions instead.
class UnitDef {
  final String id;
  final String symbol;
  final double factor;
  final UnitL10n name;
  final double Function(double value)? toBase;
  final double Function(double base)? fromBase;

  const UnitDef({
    required this.id,
    required this.symbol,
    required this.name,
    this.factor = 1.0,
    this.toBase,
    this.fromBase,
  });

  double convertToBase(double value) =>
      toBase != null ? toBase!(value) : value * factor;

  double convertFromBase(double base) =>
      fromBase != null ? fromBase!(base) : base / factor;
}

/// A group of related units sharing a common base unit.
class UnitCategory {
  final String id;
  final IconData icon;
  final UnitL10n name;
  final List<UnitDef> units;

  const UnitCategory({
    required this.id,
    required this.icon,
    required this.name,
    required this.units,
  });

  UnitDef? unitById(String unitId) {
    for (final u in units) {
      if (u.id == unitId) return u;
    }
    return null;
  }

  /// Converts [value] expressed in [from] into [to].
  double convert(double value, UnitDef from, UnitDef to) {
    final base = from.convertToBase(value);
    return to.convertFromBase(base);
  }
}
