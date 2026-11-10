import 'package:html/parser.dart' as html_parser;

import '../models/x_media.dart';
import '../models/x_post.dart';
import '../models/x_user.dart';

/// Turns X's GraphQL timeline JSON into posts. Ads (`promoted-*` entries and
/// items carrying `promotedMetadata`) and recommendation modules never make it
/// out of here.
class XTimelineParser {
  XTimelineParser._();

  static const List<String> _skippedEntryPrefixes = [
    'promoted',
    'who-to-follow',
    'who-to-subscribe',
    'trends',
    'explore',
    'community',
    'tweetdetailrelatedtweets',
    'list-',
    'messageprompt',
    'premium',
    'subscribe',
    'superfollow',
    'grok',
  ];

  static XTimelinePage parse(Object? json) {
    final posts = <XPost>[];
    final seen = <String>{};
    String? bottom;

    void addItem(Map? itemContent) {
      if (itemContent == null) return;
      if (itemContent['promotedMetadata'] != null) return;
      if (itemContent['itemType'] == 'TimelineTimelineCursor' ||
          itemContent['__typename'] == 'TimelineTimelineCursor') {
        final type = itemContent['cursorType'];
        if (type == 'Bottom' || type == 'ShowMoreThreads') {
          bottom ??= itemContent['value'] as String?;
        }
        return;
      }
      final post = parseTweet(_path(itemContent, ['tweet_results', 'result']));
      if (post != null && seen.add(post.id)) posts.add(post);
    }

    void addEntry(Map entry) {
      final entryId = (entry['entryId'] as String? ?? '').toLowerCase();
      if (_skippedEntryPrefixes.any(entryId.startsWith)) return;
      final content = entry['content'];
      if (content is! Map) return;
      final type = content['entryType'] ?? content['__typename'];
      if (type == 'TimelineTimelineCursor') {
        if (content['cursorType'] == 'Bottom') {
          bottom = content['value'] as String?;
        }
        return;
      }
      if (type == 'TimelineTimelineItem') {
        addItem(content['itemContent'] as Map?);
      } else if (type == 'TimelineTimelineModule') {
        for (final item in content['items'] as List? ?? const []) {
          addItem(_path(item, ['item', 'itemContent']) as Map?);
        }
      }
    }

    for (final instruction in _findInstructions(json)) {
      if (instruction is! Map) continue;
      switch (instruction['type']) {
        case 'TimelineAddEntries':
          for (final entry in instruction['entries'] as List? ?? const []) {
            if (entry is Map) addEntry(entry);
          }
        case 'TimelinePinEntry':
        case 'TimelineReplaceEntry':
          final entry = instruction['entry'];
          if (entry is Map) addEntry(entry);
        case 'TimelineAddToModule':
          for (final item in instruction['moduleItems'] as List? ?? const []) {
            addItem(_path(item, ['item', 'itemContent']) as Map?);
          }
      }
    }
    return XTimelinePage(posts: posts, bottomCursor: bottom);
  }

  static List<Object?> _findInstructions(Object? node, [int depth = 0]) {
    if (depth > 12) return const [];
    if (node is Map) {
      final direct = node['instructions'];
      if (direct is List) return direct;
      for (final value in node.values) {
        final found = _findInstructions(value, depth + 1);
        if (found.isNotEmpty) return found;
      }
    }
    return const [];
  }

  static Object? _path(Object? node, List<String> keys) {
    var current = node;
    for (final key in keys) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  static XUser? parseUser(Object? result) {
    if (result is! Map) return null;
    final legacy = result['legacy'] as Map? ?? const {};
    final core = result['core'] as Map? ?? const {};
    final screenName =
        (core['screen_name'] ?? legacy['screen_name']) as String?;
    if (screenName == null) return null;
    return XUser(
      id: result['rest_id'] as String? ?? '',
      name: (core['name'] ?? legacy['name']) as String? ?? screenName,
      screenName: screenName,
      avatarUrl:
          (_path(result, ['avatar', 'image_url']) ??
                  legacy['profile_image_url_https'])
              as String?,
      verified:
          result['is_blue_verified'] == true || legacy['verified'] == true,
      bio:
          (_path(result, ['profile_bio', 'description']) ??
                  legacy['description'])
              as String?,
      bannerUrl: legacy['profile_banner_url'] as String?,
      followers: (legacy['followers_count'] as num?)?.toInt(),
      following: (legacy['friends_count'] as num?)?.toInt(),
      postCount: (legacy['statuses_count'] as num?)?.toInt(),
    );
  }

  static XPost? parseTweet(Object? raw) {
    var result = raw;
    if (result is Map && result['__typename'] == 'TweetWithVisibilityResults') {
      result = result['tweet'];
    }
    if (result is! Map) return null;
    final legacy = result['legacy'];
    if (legacy is! Map) return null;

    final author = parseUser(_path(result, ['core', 'user_results', 'result']));
    if (author == null) return null;

    final retweeted = _path(legacy, ['retweeted_status_result', 'result']);
    if (retweeted != null) {
      final inner = parseTweet(retweeted);
      if (inner != null) {
        return XPost(
          id: inner.id,
          author: inner.author,
          text: inner.text,
          links: inner.links,
          createdAt: inner.createdAt,
          media: inner.media,
          engagement: inner.engagement,
          quoted: inner.quoted,
          repostedBy: author,
          replyToScreenName: inner.replyToScreenName,
          card: inner.card,
          replies: inner.replies,
          quotes: inner.quotes,
          views: inner.views,
        );
      }
    }

    final media = _parseMedia(legacy);
    final (text, links) = _parseText(result, legacy, media.isNotEmpty);
    final id = (result['rest_id'] ?? legacy['id_str']) as String? ?? '';
    if (id.isEmpty) return null;

    return XPost(
      id: id,
      author: author,
      text: text,
      links: links,
      createdAt: parseDate(legacy['created_at'] as String?),
      media: media,
      quoted: parseTweet(_path(result, ['quoted_status_result', 'result'])),
      replyToScreenName: legacy['in_reply_to_screen_name'] as String?,
      card: _parseCard(result['card'], links),
      replies: _int(legacy['reply_count']),
      quotes: _int(legacy['quote_count']),
      views: int.tryParse('${_path(result, ['views', 'count']) ?? ''}'),
      engagement: XEngagement(
        liked: legacy['favorited'] == true,
        reposted: legacy['retweeted'] == true,
        bookmarked: legacy['bookmarked'] == true,
        likes: _int(legacy['favorite_count']),
        reposts: _int(legacy['retweet_count']),
      ),
    );
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;

  static List<XMedia> _parseMedia(Map legacy) {
    final list =
        _path(legacy, ['extended_entities', 'media']) as List? ??
        _path(legacy, ['entities', 'media']) as List? ??
        const [];
    final media = <XMedia>[];
    for (final m in list) {
      if (m is! Map) continue;
      final image = m['media_url_https'] as String?;
      if (image == null) continue;
      final type = switch (m['type']) {
        'video' => XMediaType.video,
        'animated_gif' => XMediaType.gif,
        _ => XMediaType.photo,
      };
      final info = m['original_info'] as Map? ?? const {};
      media.add(
        XMedia(
          type: type,
          imageUrl: image,
          width: _int(info['width']),
          height: _int(info['height']),
          videoUrl: type == XMediaType.photo
              ? null
              : bestMp4(_path(m, ['video_info', 'variants']) as List?),
          durationMs: (_path(m, ['video_info', 'duration_millis']) as num?)
              ?.toInt(),
          altText: m['ext_alt_text'] as String?,
        ),
      );
    }
    return media;
  }

  static String? bestMp4(List? variants) {
    String? best;
    var bestRate = -1;
    for (final v in variants ?? const []) {
      if (v is! Map || v['content_type'] != 'video/mp4') continue;
      final rate = _int(v['bitrate']);
      if (rate > bestRate && v['url'] is String) {
        best = v['url'] as String;
        bestRate = rate;
      }
    }
    return best;
  }

  static (String, List<XLink>) _parseText(
    Map result,
    Map legacy,
    bool hasMedia,
  ) {
    final note = _path(result, ['note_tweet', 'note_tweet_results', 'result']);
    String text;
    List urls;
    if (note is Map && note['text'] is String) {
      text = note['text'] as String;
      urls = _path(note, ['entity_set', 'urls']) as List? ?? const [];
    } else {
      text = legacy['full_text'] as String? ?? '';
      urls = _path(legacy, ['entities', 'urls']) as List? ?? const [];
      final range = legacy['display_text_range'];
      if (range is List && range.length == 2) {
        final runes = text.runes.toList();
        final start = (range[0] as num).toInt().clamp(0, runes.length);
        final end = (range[1] as num).toInt().clamp(start, runes.length);
        text = String.fromCharCodes(runes.sublist(start, end));
      }
    }

    final links = <XLink>[];
    for (final u in urls) {
      if (u is! Map) continue;
      final short = u['url'] as String?;
      final expanded = u['expanded_url'] as String?;
      if (short == null || expanded == null) continue;
      final display = u['display_url'] as String? ?? expanded;
      text = text.replaceAll(short, display);
      links.add(XLink(display: display, url: expanded));
    }
    if (hasMedia) {
      text = text.replaceAll(RegExp(r'\s*https://t\.co/\w+\s*$'), '');
    }
    return (_unescape(text).trim(), links);
  }

  static String _unescape(String text) {
    if (!text.contains('&')) return text;
    return html_parser.parseFragment(text).text ?? text;
  }

  static XLinkCard? _parseCard(Object? card, List<XLink> links) {
    final values = _path(card, ['legacy', 'binding_values']);
    if (values is! List) return null;
    final map = <String, Map>{};
    for (final v in values) {
      if (v is Map && v['key'] is String && v['value'] is Map) {
        map[v['key'] as String] = v['value'] as Map;
      }
    }
    final title = map['title']?['string_value'] as String?;
    if (title == null) return null;
    // The card belongs to the post's last link; its own card_url is a t.co.
    final url =
        links.lastOrNull?.url ?? map['card_url']?['string_value'] as String?;
    if (url == null) return null;
    final image =
        map['summary_photo_image_large'] ??
        map['thumbnail_image_large'] ??
        map['photo_image_full_size_large'] ??
        map['thumbnail_image'];
    return XLinkCard(
      url: url,
      title: title,
      domain: (map['vanity_url'] ?? map['domain'])?['string_value'] as String?,
      imageUrl: _path(image, ['image_value', 'url']) as String?,
    );
  }

  static const _months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  /// X's legacy format: `Wed Oct 10 20:19:24 +0000 2018`, always UTC.
  static DateTime? parseDate(String? value) {
    if (value == null) return null;
    final parts = value.split(' ');
    if (parts.length != 6) return null;
    final month = _months[parts[1]];
    final day = int.tryParse(parts[2]);
    final year = int.tryParse(parts[5]);
    final time = parts[3].split(':').map(int.tryParse).toList();
    if (month == null || day == null || year == null || time.length != 3) {
      return null;
    }
    if (time.any((t) => t == null)) return null;
    return DateTime.utc(year, month, day, time[0]!, time[1]!, time[2]!);
  }
}
