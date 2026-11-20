import 'x_broadcast.dart';
import 'x_media.dart';
import 'x_user.dart';

class XLink {
  /// What the text shows in place of the t.co wrapper.
  final String display;
  final String url;

  const XLink({required this.display, required this.url});
}

class XLinkCard {
  final String url;
  final String? title;
  final String? domain;
  final String? imageUrl;

  const XLinkCard({required this.url, this.title, this.domain, this.imageUrl});
}

class XEngagement {
  final bool liked;
  final bool reposted;
  final bool bookmarked;
  final int likes;
  final int reposts;

  const XEngagement({
    required this.liked,
    required this.reposted,
    required this.bookmarked,
    required this.likes,
    required this.reposts,
  });

  XEngagement copyWith({
    bool? liked,
    bool? reposted,
    bool? bookmarked,
    int? likes,
    int? reposts,
  }) => XEngagement(
    liked: liked ?? this.liked,
    reposted: reposted ?? this.reposted,
    bookmarked: bookmarked ?? this.bookmarked,
    likes: likes ?? this.likes,
    reposts: reposts ?? this.reposts,
  );
}

class XTranslation {
  final String text;
  final List<XLink> links;
  final String? sourceLanguage;

  /// The language it was translated into, when X says so.
  final String? language;

  const XTranslation({
    required this.text,
    required this.links,
    this.sourceLanguage,
    this.language,
  });
}

/// One of X's timeline feedback actions, such as "Not interested in this
/// post", as the For you timeline offers it per post.
class XFeedback {
  /// X's `feedbackUrl`, relative to `/i/api`, carrying the action metadata.
  final String url;
  final String type;

  /// X's own confirmation text, in the client language.
  final String? confirmation;
  final bool canUndo;

  const XFeedback({
    required this.url,
    required this.type,
    this.confirmation,
    this.canUndo = false,
  });
}

class XPost {
  final String id;
  final XUser author;
  final String text;
  final List<XLink> links;
  final DateTime? createdAt;
  final List<XMedia> media;
  final XPost? quoted;
  final XUser? repostedBy;

  /// The repost's own id, while [id] is the reposted post's.
  final String? repostId;
  final String? replyToScreenName;
  final String? replyToId;
  final XLinkCard? card;
  final XBroadcast? broadcast;
  final int replies;
  final int quotes;
  final int? views;
  final XEngagement engagement;

  /// X's language tag for the text, e.g. `fr`; `und` or null when unknown.
  final String? lang;
  final bool translatable;

  /// The Grok translation X sometimes sends along, in the client language.
  final XTranslation? inlineTranslation;

  /// Only For you posts carry it.
  final XFeedback? notInterested;

  const XPost({
    required this.id,
    required this.author,
    required this.text,
    required this.links,
    required this.createdAt,
    required this.media,
    required this.engagement,
    this.quoted,
    this.repostedBy,
    this.repostId,
    this.replyToScreenName,
    this.replyToId,
    this.card,
    this.broadcast,
    this.replies = 0,
    this.quotes = 0,
    this.views,
    this.lang,
    this.translatable = false,
    this.inlineTranslation,
    this.notInterested,
  });

  String get url => 'https://x.com/${author.screenName}/status/$id';

  bool get isRepost => repostedBy != null;

  /// Ids reported to X as seen; a repost reports itself and the original.
  List<String> get seenIds => [id, ?repostId];
  bool get isReply => replyToScreenName != null;

  /// English and German posts are never offered for translation. X's flag
  /// alone misses some posts it did send a translation for.
  bool get canTranslate =>
      (translatable || inlineTranslation != null) &&
      text.isNotEmpty &&
      lang != 'en' &&
      lang != 'de';

  List<XMedia> get allMedia => [...media, ...?quoted?.media];
}

class XTimelinePage {
  final List<XPost> posts;
  final String? bottomCursor;

  const XTimelinePage({required this.posts, this.bottomCursor});
}
