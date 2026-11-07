import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'news_article.dart';

class ParsedFeedItem {
  final String guidKey;
  final String title;
  final String summary;
  final String? author;
  final String link;
  final String? imageUrl;
  final int publishedAt;
  final String contentHtml;

  const ParsedFeedItem({
    required this.guidKey,
    required this.title,
    required this.summary,
    required this.author,
    required this.link,
    required this.imageUrl,
    required this.publishedAt,
    required this.contentHtml,
  });

  NewsArticle toArticle({
    required String sourceShortId,
    required int fetchedAt,
  }) {
    return NewsArticle(
      guidKey: guidKey,
      sourceShortId: sourceShortId,
      title: title,
      summary: summary,
      author: author,
      link: link,
      imageUrl: imageUrl,
      publishedAt: publishedAt > 0 ? publishedAt : fetchedAt,
      fetchedAt: fetchedAt,
      hasPublicationDate: publishedAt > 0,
    );
  }
}

class ParsedFeed {
  final String title;
  final String siteUrl;
  final List<ParsedFeedItem> items;

  const ParsedFeed({
    required this.title,
    required this.siteUrl,
    required this.items,
  });
}

class FeedParseException implements Exception {
  final String message;

  const FeedParseException(this.message);

  @override
  String toString() => message;
}

/// Parses RSS 2.0, RSS 1.0 (RDF) and Atom 1.0 without a platform channel.
class NewsFeedParser {
  static const int _maxItems = 80;
  static const int _maxSummaryChars = 420;

  static final Map<String, int> _timezoneOffsets = {
    'GMT': 0,
    'UT': 0,
    'UTC': 0,
    'Z': 0,
    'EST': -5,
    'EDT': -4,
    'CST': -6,
    'CDT': -5,
    'MST': -7,
    'MDT': -6,
    'PST': -8,
    'PDT': -7,
  };

  static ParsedFeed parse(
    String body, {
    required String sourceShortId,
    required String feedUrl,
  }) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } catch (e) {
      throw FeedParseException('Invalid XML: $e');
    }

    final root = document.rootElement;
    final rootName = root.name.local.toLowerCase();
    final List<XmlElement> itemElements;
    String feedTitle;
    String siteUrl;

    if (rootName == 'feed') {
      itemElements = root
          .findElements('entry', namespaceUri: '*')
          .take(_maxItems)
          .toList();
      feedTitle = _textOf(root, const ['title']);
      siteUrl = _atomLink(root, preferAlternate: true);
    } else if (rootName == 'rdf') {
      itemElements = root
          .findElements('item', namespaceUri: '*')
          .take(_maxItems)
          .toList();
      final channel = _firstChild(root, const ['channel']);
      feedTitle = channel == null ? '' : _textOf(channel, const ['title']);
      siteUrl = channel == null ? '' : _textOf(channel, const ['link']);
    } else {
      final channel = _firstChild(root, const ['channel']);
      if (channel == null) {
        throw const FeedParseException('Not an RSS or Atom feed');
      }
      itemElements = channel
          .findElements('item', namespaceUri: '*')
          .take(_maxItems)
          .toList();
      feedTitle = _textOf(channel, const ['title']);
      siteUrl = _textOf(channel, const ['link']);
    }

    if (itemElements.isEmpty) {
      throw const FeedParseException('Feed has no entries');
    }

    final items = <ParsedFeedItem>[];
    final seen = <String>{};
    for (final element in itemElements) {
      final item = _parseItem(
        element,
        sourceShortId: sourceShortId,
        feedUrl: feedUrl,
      );
      if (item == null) continue;
      if (!seen.add(item.guidKey)) continue;
      items.add(item);
    }

    if (items.isEmpty) {
      throw const FeedParseException('Feed has no usable entries');
    }

    return ParsedFeed(
      title: _cleanText(feedTitle, maxChars: 120),
      siteUrl: _resolveHttpUrl(siteUrl, feedUrl) ?? feedUrl,
      items: items,
    );
  }

  static ParsedFeedItem? _parseItem(
    XmlElement element, {
    required String sourceShortId,
    required String feedUrl,
  }) {
    final title = _cleanText(_textOf(element, const ['title']), maxChars: 400);
    var link = _textOf(element, const ['link']).trim();
    var guid = _textOf(element, const ['guid', 'id']).trim();

    if (link.isEmpty && element.name.local.toLowerCase() == 'entry') {
      link = _atomLink(element, preferAlternate: true);
    }
    if (link.isEmpty) {
      link = element.getAttribute('about') ?? '';
    }
    if (guid.isEmpty && link.isEmpty) return null;

    final contentHtml = _textOf(element, const [
      'encoded',
      'content',
      'description',
      'summary',
    ]);
    final summaryHtml = _textOf(element, const ['summary', 'description']);
    final summary = _plainText(
      summaryHtml.isNotEmpty ? summaryHtml : contentHtml,
      maxChars: _maxSummaryChars,
    );

    final publishedAt = parseFeedDate(
      _textOf(element, const [
        'pubDate',
        'published',
        'updated',
        'date',
        'created',
      ]),
    );

    final image = _imageFromElement(element);
    String? imageUrl = image == null ? null : _resolveHttpUrl(image, feedUrl);
    imageUrl ??= _firstImageInHtml(contentHtml, feedUrl);

    return ParsedFeedItem(
      guidKey: _guidKey(sourceShortId, guid.isNotEmpty ? guid : link),
      title: title,
      summary: summary,
      author: _authorOf(element),
      link: _resolveHttpUrl(link, feedUrl) ?? link,
      imageUrl: imageUrl,
      publishedAt: publishedAt,
      contentHtml: contentHtml,
    );
  }

  static String _guidKey(String sourceShortId, String identity) {
    return sha1.convert(utf8.encode('$sourceShortId|$identity')).toString();
  }

  static String? _authorOf(XmlElement element) {
    final authorEl = _firstChild(element, const ['author', 'creator']);
    if (authorEl == null) return null;
    final name = _firstChild(authorEl, const ['name']);
    final text = _cleanText(
      name?.innerText ?? authorEl.innerText,
      maxChars: 120,
    );
    return text.isEmpty ? null : text;
  }

  static String? _imageFromElement(XmlElement element) {
    for (final enclosure in element.findAllElements(
      'enclosure',
      namespaceUri: '*',
    )) {
      final url = enclosure.getAttribute('url');
      final type = enclosure.getAttribute('type') ?? '';
      if (url != null && (type.startsWith('image/') || _looksLikeImage(url))) {
        return url.trim();
      }
    }
    for (final tag in const ['content', 'thumbnail']) {
      for (final media in element.findAllElements(tag, namespaceUri: '*')) {
        final url = media.getAttribute('url');
        if (url == null) continue;
        final type = media.getAttribute('type') ?? '';
        final medium = media.getAttribute('medium') ?? '';
        if (type.startsWith('image/') ||
            medium == 'image' ||
            _looksLikeImage(url)) {
          return url.trim();
        }
      }
    }
    for (final image in element.findAllElements('image', namespaceUri: '*')) {
      final url = image.getAttribute('href') ?? image.getAttribute('url');
      if (url != null) return url.trim();
    }
    for (final link in element.findAllElements('link', namespaceUri: '*')) {
      final rel = link.getAttribute('rel') ?? '';
      final type = link.getAttribute('type') ?? '';
      final href = link.getAttribute('href');
      if (href != null && rel == 'enclosure' && type.startsWith('image/')) {
        return href;
      }
    }
    return null;
  }

  static String? _firstImageInHtml(String html, String baseUrl) {
    if (html.isEmpty) return null;
    final doc = html_parser.parseFragment(html);
    for (final img in doc.querySelectorAll('img')) {
      final src =
          img.attributes['src'] ??
          img.attributes['data-src'] ??
          img.attributes['data-lazy-src'];
      if (src == null || src.isEmpty || src.startsWith('data:')) continue;
      final resolved = _resolveHttpUrl(src, baseUrl);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static bool _looksLikeImage(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.avif') ||
        path.endsWith('.gif');
  }

  static String _textOf(XmlElement element, List<String> localNames) {
    for (final name in localNames) {
      for (final child in element.findElements(name, namespaceUri: '*')) {
        final text = child.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  static XmlElement? _firstChild(XmlElement element, List<String> localNames) {
    for (final name in localNames) {
      for (final child in element.findElements(name, namespaceUri: '*')) {
        return child;
      }
    }
    return null;
  }

  static String _atomLink(XmlElement element, {required bool preferAlternate}) {
    var fallback = '';
    for (final link in element.findElements('link', namespaceUri: '*')) {
      final href = link.getAttribute('href');
      if (href == null || href.trim().isEmpty) continue;
      final rel = link.getAttribute('rel') ?? 'alternate';
      if (rel == 'alternate') return href.trim();
      if (preferAlternate && fallback.isEmpty && rel == 'self') {
        fallback = href.trim();
      }
    }
    return fallback;
  }

  static String _plainText(String html, {required int maxChars}) {
    if (html.isEmpty) return '';
    final withBreaks = html.replaceAll(
      RegExp(r'<(br|/p|/div|/li|/h[1-6])\s*/?>', caseSensitive: false),
      ' ',
    );
    var text = html_parser.parseFragment(withBreaks).text ?? '';
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _cleanText(text, maxChars: maxChars);
  }

  static String _cleanText(String text, {required int maxChars}) {
    final cleaned = text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= maxChars) return cleaned;
    final cut = cleaned.substring(0, maxChars);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > maxChars * 0.6 ? cut.substring(0, lastSpace) : cut}…';
  }

  static String? _resolveHttpUrl(String raw, String baseUrl) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return uri.scheme == 'http' || uri.scheme == 'https'
          ? uri.toString()
          : null;
    }
    final base = Uri.tryParse(baseUrl);
    if (base == null) return null;
    return base.resolveUri(uri).toString();
  }

  /// RSS dates are RFC 822 with loose timezone handling; Atom uses ISO 8601.
  /// Returns 0 when the feed omits a usable date.
  static int parseFeedDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 0;
    try {
      return HttpDate.parse(text).millisecondsSinceEpoch;
    } catch (_) {}
    try {
      return DateTime.parse(text).toUtc().millisecondsSinceEpoch;
    } catch (_) {}

    var normalized = text;
    final tzMatch = RegExp(r'\s([A-Z]{2,4})$').firstMatch(text);
    if (tzMatch != null) {
      final offset = _timezoneOffsets[tzMatch.group(1)!];
      if (offset != null) {
        normalized =
            '${text.substring(0, tzMatch.start)} '
            '${offset >= 0 ? '+' : '-'}${offset.abs().toString().padLeft(2, '0')}00';
      }
    }
    final manual = _parseRfc822(normalized);
    if (manual != null) return manual;
    const patterns = [
      'EEE, dd MMM yyyy HH:mm:ss Z',
      'EEE, d MMM yyyy HH:mm:ss Z',
      'EEE, dd MMM yyyy HH:mm Z',
      'EEE, d MMM yyyy HH:mm Z',
      'dd MMM yyyy HH:mm:ss Z',
      'dd MMM yyyy HH:mm Z',
      'yyyy-MM-dd HH:mm:ss Z',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
    ];
    for (final pattern in patterns) {
      try {
        final parsed = DateFormat(pattern, 'en_US').parseStrict(normalized);
        return parsed.toUtc().millisecondsSinceEpoch;
      } catch (_) {}
    }
    return 0;
  }

  static const Map<String, int> _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static int? _parseRfc822(String text) {
    final match = RegExp(
      r'^(?:[A-Za-z]{3},?\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*'
      r'([+-]\d{2}:?\d{2}|[A-Za-z]{2,4})$',
    ).firstMatch(text.trim());
    if (match == null) return null;
    final month = _months[match.group(2)!.toLowerCase()];
    if (month == null) return null;

    final tz = match.group(7)!;
    final int offsetMinutes;
    if (tz.startsWith('+') || tz.startsWith('-')) {
      final digits = tz.replaceAll(':', '');
      final hours = int.tryParse(digits.substring(1, 3));
      final minutes = int.tryParse(digits.substring(3, 5));
      if (hours == null || minutes == null) return null;
      final sign = digits.startsWith('-') ? -1 : 1;
      offsetMinutes = sign * ((hours * 60) + minutes);
    } else {
      final hours = _timezoneOffsets[tz.toUpperCase()];
      if (hours == null) return null;
      offsetMinutes = hours * 60;
    }

    final local = DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.tryParse(match.group(6) ?? '') ?? 0,
    );
    return local.millisecondsSinceEpoch - (offsetMinutes * 60000);
  }
}
