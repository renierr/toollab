class NewsCachedContent {
  final String? markdown;
  final List<String>? videoUrls;

  const NewsCachedContent({required this.markdown, required this.videoUrls});
}

class NewsArticle {
  final int? id;
  final String guidKey;
  final String sourceShortId;
  final String title;
  final String summary;
  final String? author;
  final String link;
  final String? imageUrl;
  final int publishedAt;
  final String? contentMarkdown;
  final int? readAt;
  final int fetchedAt;
  final bool agedOut;
  final bool hasPublicationDate;

  const NewsArticle({
    this.id,
    required this.guidKey,
    required this.sourceShortId,
    required this.title,
    this.summary = '',
    this.author,
    required this.link,
    this.imageUrl,
    required this.publishedAt,
    this.contentMarkdown,
    this.readAt,
    required this.fetchedAt,
    this.agedOut = false,
    this.hasPublicationDate = true,
  });

  bool get isRead => readAt != null || agedOut;

  NewsArticle copyWith({
    int? id,
    String? guidKey,
    String? sourceShortId,
    String? title,
    String? summary,
    String? author,
    String? link,
    String? imageUrl,
    int? publishedAt,
    String? contentMarkdown,
    int? readAt,
    int? fetchedAt,
    bool? agedOut,
    bool? hasPublicationDate,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      guidKey: guidKey ?? this.guidKey,
      sourceShortId: sourceShortId ?? this.sourceShortId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      author: author ?? this.author,
      link: link ?? this.link,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      contentMarkdown: contentMarkdown ?? this.contentMarkdown,
      readAt: readAt ?? this.readAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      agedOut: agedOut ?? this.agedOut,
      hasPublicationDate: hasPublicationDate ?? this.hasPublicationDate,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'guid_key': guidKey,
      'source_short_id': sourceShortId,
      'title': title,
      'summary': summary,
      'author': author,
      'link': link,
      'image_url': imageUrl,
      'published_at': publishedAt,
      'content_md': contentMarkdown,
      'read_at': readAt,
      'fetched_at': fetchedAt,
    };
  }

  factory NewsArticle.fromMap(Map<String, Object?> map) {
    return NewsArticle(
      id: map['id'] as int?,
      guidKey: map['guid_key'] as String? ?? '',
      sourceShortId: map['source_short_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      author: map['author'] as String?,
      link: map['link'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      publishedAt: map['published_at'] as int? ?? 0,
      contentMarkdown: map['content_md'] as String?,
      readAt: map['read_at'] as int?,
      fetchedAt: map['fetched_at'] as int? ?? 0,
    );
  }
}
