import 'dart:convert';
import 'package:tool_lab/services/database_service.dart';

class HistoryItem {
  final String id;
  final String expression;
  final String result;
  final int timestamp;

  const HistoryItem({
    required this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'expression': expression,
    'result': result,
    'timestamp': timestamp,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as String? ?? '',
    expression: json['expression'] as String? ?? '',
    result: json['result'] as String? ?? '',
    timestamp: json['timestamp'] as int? ?? 0,
  );
}

class HistoryManager {
  static const String _storageKey = 'calculator_history_v1';
  static const int _maxItems = 20;

  List<HistoryItem> _items = [];

  List<HistoryItem> get items => List.unmodifiable(_items);

  Future<void> load() async {
    try {
      final raw = await DatabaseService.instance.getSetting(
        'calculator',
        _storageKey,
      );
      if (raw == null || raw.isEmpty) {
        _items = [];
        return;
      }
      final list = jsonDecode(raw) as List<dynamic>;
      _items = list
          .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
          .where((item) => item.id.isNotEmpty)
          .toList();
      _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      _items = [];
    }
  }

  Future<void> _save() async {
    try {
      final json = jsonEncode(_items.map((e) => e.toJson()).toList());
      await DatabaseService.instance.setSetting(
        'calculator',
        _storageKey,
        json,
      );
    } catch (_) {}
  }

  Future<HistoryItem> addItem(String expression, String result) async {
    final item = HistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      expression: expression,
      result: result,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _items.insert(0, item);
    if (_items.length > _maxItems) {
      _items = _items.sublist(0, _maxItems);
    }
    await _save();
    return item;
  }

  Future<void> clear() async {
    _items = [];
    await _save();
  }

  HistoryItem? get lastItem => _items.isNotEmpty ? _items.first : null;
}
