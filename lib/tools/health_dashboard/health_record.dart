import 'dart:convert';

enum HealthSource { healthConnect, treadmill, manual }

class HealthRecord {
  final String id;
  final HealthSource source;
  final String sourceRecordId;
  final String type;
  final int startTime;
  final int endTime;
  final Map<String, dynamic> value;
  final String? sourceName;
  final String? duplicateOf;
  final bool aggregateIncluded;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final bool synced;

  const HealthRecord({
    required this.id,
    required this.source,
    required this.sourceRecordId,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.value,
    this.sourceName,
    this.duplicateOf,
    required this.aggregateIncluded,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    required this.synced,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'source': source.name,
    'source_record_id': sourceRecordId,
    'type': type,
    'start_time': startTime,
    'end_time': endTime,
    'value_json': jsonEncode(value),
    'source_name': sourceName,
    'duplicate_of': duplicateOf,
    'aggregate_included': aggregateIncluded ? 1 : 0,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted': deleted ? 1 : 0,
    'synced': synced ? 1 : 0,
  };

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    final rawValue = map['value_json'];
    return HealthRecord(
      id: map['id'] as String,
      source: HealthSource.values.byName(map['source'] as String),
      sourceRecordId: map['source_record_id'] as String,
      type: map['type'] as String,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int,
      value: rawValue is String
          ? Map<String, dynamic>.from(jsonDecode(rawValue) as Map)
          : Map<String, dynamic>.from(rawValue as Map),
      sourceName: map['source_name'] as String?,
      duplicateOf: map['duplicate_of'] as String?,
      aggregateIncluded: (map['aggregate_included'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deleted: (map['deleted'] as int? ?? 0) == 1,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }

  HealthRecord copyWith({
    String? duplicateOf,
    bool? aggregateIncluded,
    int? updatedAt,
    bool? deleted,
    bool? synced,
  }) => HealthRecord(
    id: id,
    source: source,
    sourceRecordId: sourceRecordId,
    type: type,
    startTime: startTime,
    endTime: endTime,
    value: value,
    sourceName: sourceName,
    duplicateOf: duplicateOf ?? this.duplicateOf,
    aggregateIncluded: aggregateIncluded ?? this.aggregateIncluded,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    synced: synced ?? this.synced,
  );
}
