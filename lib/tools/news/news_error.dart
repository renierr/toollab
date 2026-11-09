enum NewsError {
  invalidUrl,
  unreachable,
  httpStatus,
  tooLarge,
  invalidXml,
  notAFeed,
  noEntries,
  notHtml,
  noArticleBody,
}

class NewsException implements Exception {
  final NewsError error;
  final int? status;

  const NewsException(this.error, {this.status});

  /// Language-neutral form stored as a source's last error; the UI maps it
  /// back to text in [newsErrorText].
  String get code => status == null ? error.name : '${error.name}:$status';

  @override
  String toString() => code;
}
