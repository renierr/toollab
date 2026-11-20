import 'dart:convert';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/weather_warning.dart';

/// Decides which warnings are worth a notification, announcing each at most
/// once. Nowcast ids change with every model run, so a warning also counts as
/// announced while one with the same event and level still overlaps it.
class WeatherWarningAlerts {
  WeatherWarningAlerts({DatabaseService? db})
    : _db = db ?? DatabaseService.instance;

  static const String _key = 'announced_warnings';

  /// Kept this long when a warning has no end.
  static const Duration _openEndedKeep = Duration(hours: 24);

  final DatabaseService _db;

  /// Warnings from [minLevel] up not announced yet, marked announced on return.
  /// [minLevel] 0 turns notifications off.
  Future<List<WeatherWarning>> takeNew(
    List<WeatherWarning> warnings,
    int minLevel,
    DateTime now,
  ) async {
    if (minLevel <= 0) return const [];
    final announced = await _load(now);
    final fresh = <WeatherWarning>[];
    for (final w in warnings) {
      if (w.level < minLevel) continue;
      if (announced.any((a) => a.covers(w))) continue;
      fresh.add(w);
      announced.add(_Announced.of(w));
    }
    if (fresh.isNotEmpty) await _save(announced);
    return fresh;
  }

  Future<List<_Announced>> _load(DateTime now) async {
    final raw = await _db.getSetting(WeatherTool.config.id, _key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List<dynamic>)
          _Announced.fromJson(e as Map<String, dynamic>),
      ]..removeWhere((a) => !a.until.isAfter(now));
    } catch (e) {
      debugLog('[WeatherWarningAlerts] unreadable state: $e');
      return [];
    }
  }

  Future<void> _save(List<_Announced> announced) => _db.setSetting(
    WeatherTool.config.id,
    _key,
    jsonEncode([for (final a in announced) a.toJson()]),
  );
}

class _Announced {
  const _Announced(this.id, this.event, this.level, this.until);

  factory _Announced.of(WeatherWarning w) => _Announced(
    w.id,
    w.event,
    w.level,
    w.end ?? w.start.add(WeatherWarningAlerts._openEndedKeep),
  );

  factory _Announced.fromJson(Map<String, dynamic> json) => _Announced(
    json['id'] as String,
    json['event'] as String,
    (json['level'] as num).toInt(),
    DateTime.fromMillisecondsSinceEpoch(
      (json['until'] as num).toInt(),
      isUtc: true,
    ),
  );

  final String id;
  final String event;
  final int level;
  final DateTime until;

  bool covers(WeatherWarning w) =>
      (id.isNotEmpty && id == w.id) ||
      (event == w.event && level >= w.level && !until.isBefore(w.start));

  Map<String, Object> toJson() => {
    'id': id,
    'event': event,
    'level': level,
    'until': until.millisecondsSinceEpoch,
  };
}
