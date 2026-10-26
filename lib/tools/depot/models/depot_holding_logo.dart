import 'dart:typed_data';

class DepotHoldingLogo {
  final String key;
  final String sourceUrl;
  final Uint8List bytes;
  final DateTime fetchedAt;

  const DepotHoldingLogo({
    required this.key,
    required this.sourceUrl,
    required this.bytes,
    required this.fetchedAt,
  });

  factory DepotHoldingLogo.fromMap(Map<String, Object?> row) =>
      DepotHoldingLogo(
        key: row['asset_key'] as String,
        sourceUrl: row['source_url'] as String,
        bytes: row['data'] as Uint8List,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          row['fetched_at'] as int,
        ),
      );

  Map<String, Object?> toMap() => {
    'asset_key': key,
    'source_url': sourceUrl,
    'data': bytes,
    'fetched_at': fetchedAt.millisecondsSinceEpoch,
  };
}
