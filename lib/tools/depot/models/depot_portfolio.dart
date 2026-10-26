import 'parqet_json.dart';

class DepotPortfolio {
  final String id;
  final String name;
  final String currency;
  final DateTime? createdAt;
  final List<String> brokers;

  const DepotPortfolio({
    required this.id,
    required this.name,
    required this.currency,
    this.createdAt,
    this.brokers = const [],
  });

  factory DepotPortfolio.fromJson(Map<String, dynamic> json) => DepotPortfolio(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    currency: json['currency'] as String? ?? 'EUR',
    createdAt: ParqetJson.date(json['createdAt']),
    brokers: [
      for (final broker in json['distinctBrokers'] as List? ?? const [])
        if (broker is String) broker,
    ],
  );

  factory DepotPortfolio.fromMap(Map<String, Object?> map) => DepotPortfolio(
    id: map['id'] as String,
    name: map['name'] as String,
    currency: map['currency'] as String,
    createdAt: ParqetJson.fromEpoch(map['created_at']),
    brokers: (map['brokers'] as String? ?? '')
        .split(',')
        .where((b) => b.isNotEmpty)
        .toList(),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'currency': currency,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'brokers': brokers.join(','),
  };
}
