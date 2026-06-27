class GroceryItem {
  final int? id;
  final String shortId;
  final String name;
  final double amount;
  final String unit;
  final bool checked;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final bool synced;

  GroceryItem({
    this.id,
    required this.shortId,
    required this.name,
    this.amount = 1.0,
    this.unit = 'pcs',
    this.checked = false,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.synced = false,
  });

  GroceryItem copyWith({
    int? id,
    String? shortId,
    String? name,
    double? amount,
    String? unit,
    bool? checked,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
    bool? synced,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      shortId: shortId ?? this.shortId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'short_id': shortId,
      'name': name,
      'amount': amount,
      'unit': unit,
      'checked': checked ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
      'synced': synced ? 1 : 0,
    };
  }

  factory GroceryItem.fromMap(Map<String, dynamic> map) {
    return GroceryItem(
      id: map['id'] as int?,
      shortId: map['short_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String? ?? 'pcs',
      checked: (map['checked'] as int?) == 1,
      createdAt: map['created_at'] as int? ?? 0,
      updatedAt: map['updated_at'] as int? ?? 0,
      deleted: (map['deleted'] as int?) == 1,
      synced: (map['synced'] as int?) == 1,
    );
  }
}
