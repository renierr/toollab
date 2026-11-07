class NewsSource {
  final String shortId;
  final String title;
  final String feedUrl;
  final String siteUrl;
  final String category;
  final bool enabled;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final bool synced;

  /// Conditional-GET state; device-local so a fresh install refetches once.
  final String? etag;
  final String? lastModified;
  final int lastFetchedAt;
  final String? lastError;

  const NewsSource({
    required this.shortId,
    required this.title,
    required this.feedUrl,
    this.siteUrl = '',
    this.category = '',
    this.enabled = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.synced = false,
    this.etag,
    this.lastModified,
    this.lastFetchedAt = 0,
    this.lastError,
  });

  bool get hasError => (lastError ?? '').isNotEmpty;

  NewsSource copyWith({
    String? shortId,
    String? title,
    String? feedUrl,
    String? siteUrl,
    String? category,
    bool? enabled,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
    bool? synced,
    String? etag,
    String? lastModified,
    int? lastFetchedAt,
    String? lastError,
    bool clearError = false,
    bool clearEtag = false,
  }) {
    return NewsSource(
      shortId: shortId ?? this.shortId,
      title: title ?? this.title,
      feedUrl: feedUrl ?? this.feedUrl,
      siteUrl: siteUrl ?? this.siteUrl,
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      synced: synced ?? this.synced,
      etag: clearEtag ? null : (etag ?? this.etag),
      lastModified: clearEtag ? null : (lastModified ?? this.lastModified),
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'short_id': shortId,
      'title': title,
      'feed_url': feedUrl,
      'site_url': siteUrl,
      'category': category,
      'enabled': enabled ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
      'synced': synced ? 1 : 0,
      'etag': etag,
      'last_modified': lastModified,
      'last_fetched_at': lastFetchedAt,
      'last_error': lastError,
    };
  }

  /// Wire shape used by [NewsSyncDelegate] — no device-local fetch state.
  Map<String, dynamic> toSyncJson() {
    return {
      'title': title,
      'feedUrl': feedUrl,
      'siteUrl': siteUrl,
      'category': category,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory NewsSource.fromMap(Map<String, Object?> map) {
    return NewsSource(
      shortId: map['short_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      feedUrl: map['feed_url'] as String? ?? '',
      siteUrl: map['site_url'] as String? ?? '',
      category: map['category'] as String? ?? '',
      enabled: (map['enabled'] as int?) != 0,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] as int? ?? 0,
      updatedAt: map['updated_at'] as int? ?? 0,
      deleted: (map['deleted'] as int?) == 1,
      synced: (map['synced'] as int?) == 1,
      etag: map['etag'] as String?,
      lastModified: map['last_modified'] as String?,
      lastFetchedAt: map['last_fetched_at'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }
}
