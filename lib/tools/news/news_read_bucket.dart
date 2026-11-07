import 'dart:convert';

class NewsReadBucketMeta {
  final String id;
  final int updatedAt;

  const NewsReadBucketMeta({required this.id, required this.updatedAt});

  factory NewsReadBucketMeta.fromMap(Map<String, Object?> row) =>
      NewsReadBucketMeta(
        id: row['id'] as String,
        updatedAt: row['updated_at'] as int,
      );
}

class NewsReadBucket {
  final String id;
  final int updatedAt;
  final bool synced;
  final Map<String, int> reads;

  const NewsReadBucket({
    required this.id,
    required this.updatedAt,
    required this.synced,
    required this.reads,
  });

  factory NewsReadBucket.fromMap(Map<String, Object?> row) {
    final decoded = jsonDecode(row['reads'] as String) as Map<String, dynamic>;
    return NewsReadBucket(
      id: row['id'] as String,
      updatedAt: row['updated_at'] as int,
      synced: row['synced'] == 1,
      reads: {
        for (final entry in decoded.entries)
          if (entry.value is int) entry.key: entry.value as int,
      },
    );
  }
}
