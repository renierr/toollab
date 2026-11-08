import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html2md/html2md.dart' as html2md;
import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';

import 'news_article.dart';

class ArticleExtractException implements Exception {
  final String message;

  const ArticleExtractException(this.message);

  @override
  String toString() => message;
}

class ExtractedArticle {
  final String markdown;
  final String? imageUrl;
  final String? title;
  final List<String> videoUrls;

  const ExtractedArticle({
    required this.markdown,
    required this.imageUrl,
    required this.title,
    this.videoUrls = const [],
  });
}

/// Fetches the original page and turns its main column into Markdown.
///
/// The feed itself usually carries only a teaser, so the reader needs the
/// article body from the source. Extraction is best-effort: when a site blocks
/// us or renders client-side, the reader falls back to the feed summary.
class NewsArticleService {
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  static const Duration _timeout = Duration(seconds: 20);
  static const int _maxBytes = 6 * 1024 * 1024;
  static const int _maxMarkdownChars = 400000;

  static const List<String> _dropSelectors = [
    'script',
    'style',
    'noscript',
    'iframe',
    'svg',
    'canvas',
    'form',
    'button',
    'input',
    'select',
    'textarea',
    'nav',
    'header',
    'footer',
    'aside',
    '[role="navigation"]',
    '[role="banner"]',
    '[role="complementary"]',
    '[aria-hidden="true"]',
    '[class*="cookie"]',
    '[class*="consent"]',
    '[class*="newsletter"]',
    '[class*="subscribe"]',
    '[class*="advert"]',
    '[class*="advertisement"]',
    '[class*="sponsored"]',
    '[class*="share"]',
    '[class*="social"]',
    '[class*="related"]',
    '[class*="recommend"]',
    '[class*="promo"]',
    '[class*="paywall"]',
    '[id*="cookie"]',
    '[id*="advert"]',
    '[id*="newsletter"]',
  ];

  static const List<String> _contentSelectors = [
    '[itemprop="articleBody"]',
    '.article-body',
    '.article__body',
    '.article-content',
    '.article__content',
    '.article-text',
    '.post-content',
    '.entry-content',
    '.story-body',
    '.story-content',
    '.content__article-body',
    '.body-text',
    '.rich-text',
    '.prose',
    'article',
    'main',
    '[role="main"]',
    '#article',
    '#content',
  ];

  static Future<ExtractedArticle> fetch(
    NewsArticle article, {
    String? feedHtml,
    bool allowImageOnly = false,
  }) async {
    if (article.link.isEmpty) {
      throw const ArticleExtractException('Article has no link');
    }
    final uri = Uri.tryParse(article.link);
    if (uri == null || !uri.hasScheme) {
      throw const ArticleExtractException('Invalid article link');
    }

    final http.Response response;
    try {
      final client = await AppHttpClient.client;
      response = await client
          .get(
            uri,
            headers: const {
              'User-Agent': _userAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9,de;q=0.8',
            },
          )
          .timeout(_timeout);
    } catch (e) {
      throw ArticleExtractException('Could not load article: $e');
    }

    if (response.statusCode >= 400) {
      throw ArticleExtractException('Source answered ${response.statusCode}');
    }
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.isNotEmpty &&
        !contentType.contains('html') &&
        !contentType.contains('text/plain')) {
      throw ArticleExtractException('Source is not an HTML page');
    }
    if (response.bodyBytes.length > _maxBytes) {
      throw const ArticleExtractException('Article page is too large');
    }

    final html = _decodeBody(response);
    final extracted = extract(
      html,
      article.link,
      title: article.title,
      author: article.author,
      heroImageUrl: article.imageUrl,
    );
    if (extracted == null && feedHtml != null && feedHtml.isNotEmpty) {
      final fallback = _extractFragment(feedHtml, article.link);
      if (fallback != null) return fallback;
    }
    if (extracted == null) {
      if (allowImageOnly) {
        final image = extractImage(html, article.link);
        if (image != null) {
          return ExtractedArticle(markdown: '', imageUrl: image, title: null);
        }
      }
      throw const ArticleExtractException('Could not find the article body');
    }
    return extracted;
  }

  /// Exposed for tests and for already-downloaded pages.
  static ExtractedArticle? extract(
    String html,
    String baseUrl, {
    String? title,
    String? author,
    String? heroImageUrl,
  }) {
    final document = html_parser.parse(html);
    final baseUri = _baseUri(document, baseUrl);
    final metadataImage = _imageFromDocument(document, baseUri);
    final pageTitle = _metaContent(document, 'meta[property="og:title"]');

    for (final selector in _dropSelectors) {
      for (final element in document.querySelectorAll(selector)) {
        element.remove();
      }
    }

    final main =
        _selectMain(document) ??
        document
            .querySelectorAll('article, main')
            .where((element) => element.querySelector('video') != null)
            .firstOrNull;
    if (main == null) return null;

    final videoUrls = _videoUrls(main, baseUri);
    _prepareForMarkdown(main, baseUri);
    final image =
        metadataImage ?? main.querySelector('img[src]')?.attributes['src'];
    _deduplicate(
      main,
      title ?? pageTitle,
      author,
      heroImageUrl ?? image,
      baseUri,
    );

    final markdown = _toMarkdown(main, baseUrl);
    if (_usableLength(markdown) < 40 && videoUrls.isEmpty) return null;

    return ExtractedArticle(
      markdown: markdown,
      imageUrl: image,
      title: pageTitle,
      videoUrls: videoUrls,
    );
  }

  static String? extractImage(String html, String baseUrl) {
    final document = html_parser.parse(html);
    return _imageFromDocument(document, _baseUri(document, baseUrl));
  }

  static String? _imageFromDocument(dom.Document document, Uri baseUri) {
    return _resolve(
      _metaContent(document, 'meta[property="og:image"]') ??
          _metaContent(document, 'meta[name="twitter:image"]') ??
          '',
      baseUri,
    );
  }

  static void _deduplicate(
    dom.Element root,
    String? title,
    String? author,
    String? heroImageUrl,
    Uri baseUri,
  ) {
    String normalize(String text) =>
        text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final headline = normalize(title ?? '');
    final byline = normalize(author ?? '');
    final seenText = <String>{};
    for (final element in root.querySelectorAll(
      'h1, h2, h3, h4, h5, h6, p, div',
    )) {
      if (element.localName == 'div' &&
          element.querySelector('div, p, h1, h2, h3, h4, h5, h6, img') !=
              null) {
        continue;
      }
      final text = normalize(element.text);
      if (text.isEmpty) continue;
      if ((headline.isNotEmpty && text == headline) ||
          (byline.isNotEmpty && (text == byline || text == 'by $byline')) ||
          (text.length >= 40 && !seenText.add(text))) {
        element.remove();
      }
    }
    final seenImages = <String>{};
    final hero = heroImageUrl == null ? null : _resolve(heroImageUrl, baseUri);
    if (hero != null) seenImages.add(_imageIdentity(hero));
    for (final image in root.querySelectorAll('img[src]')) {
      final url = _imageIdentity(image.attributes['src']!);
      if (!seenImages.add(url)) image.remove();
    }
    for (final item in root.querySelectorAll('li')) {
      if (item.text.trim().isEmpty && item.querySelector('img') == null) {
        item.remove();
      }
    }
    for (final time in root.querySelectorAll('time')) {
      if (time.parent?.localName != 'p') time.remove();
    }
  }

  static String _imageIdentity(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    const dimensions = {'width', 'height', 'w', 'h', 'quality', 'q', 'format'};
    final parameters = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((key, _) => dimensions.contains(key.toLowerCase()));
    final base = uri.replace(query: '', fragment: '').toString();
    final withoutQuery = base.endsWith('?')
        ? base.substring(0, base.length - 1)
        : base;
    if (parameters.isEmpty) return withoutQuery;
    return '$withoutQuery?${Uri(queryParameters: parameters).query}';
  }

  static String cleanCachedMarkdown(
    String markdown, {
    required String title,
    String? author,
    String? heroImageUrl,
  }) {
    final seenText = <String>{};
    final seenImages = <String>{};
    if (heroImageUrl != null && heroImageUrl.isNotEmpty) {
      seenImages.add(_imageIdentity(heroImageUrl));
    }
    final headline = title.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final byline = (author ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    final imagePattern = RegExp(r'!\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)');
    var inCode = false;
    final lines = <String>[];
    for (var line in markdown.split('\n')) {
      if (line.trimLeft().startsWith('```') ||
          line.trimLeft().startsWith('~~~')) {
        inCode = !inCode;
        lines.add(line);
        continue;
      }
      if (!inCode) {
        line = line.replaceAllMapped(imagePattern, (match) {
          return seenImages.add(_imageIdentity(match.group(1)!))
              ? match.group(0)!
              : '';
        });
        final text = line
            .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final lower = text
            .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!)
            .replaceAll(RegExp(r'[*_`]'), '')
            .toLowerCase();
        if (lower == headline && headline.isNotEmpty) continue;
        if (byline.isNotEmpty && (lower == byline || lower == 'by $byline')) {
          continue;
        }
        if (lower.length >= 40 && !seenText.add(lower)) continue;
        if (RegExp(r'^\s*[-*+]\s*$').hasMatch(line)) continue;
      }
      lines.add(line);
    }
    return _cleanMarkdown(lines.join('\n'));
  }

  static ExtractedArticle? _extractFragment(String html, String baseUrl) {
    final fragment = html_parser.parseFragment(html);
    final wrapper = dom.Element.tag('div')..nodes.addAll(fragment.nodes);
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null) return null;
    final videoUrls = _videoUrls(wrapper, baseUri);
    _prepareForMarkdown(wrapper, baseUri);
    final markdown = _toMarkdown(wrapper, baseUrl);
    if (_usableLength(markdown) < 50 && videoUrls.isEmpty) return null;
    return ExtractedArticle(
      markdown: markdown,
      imageUrl: null,
      title: null,
      videoUrls: videoUrls,
    );
  }

  static List<String> _videoUrls(dom.Element root, Uri baseUri) {
    final urls = <String>{};
    for (final video in root.querySelectorAll('video')) {
      final candidates = [
        video.attributes['src'],
        ...video
            .querySelectorAll('source')
            .map((source) => source.attributes['src']),
      ];
      for (final candidate in candidates) {
        if (candidate == null) continue;
        final url = _resolve(candidate, baseUri);
        if (url != null) {
          urls.add(url);
          break;
        }
      }
      if (urls.length >= 8) break;
    }
    return urls.toList(growable: false);
  }

  static Uri _baseUri(dom.Document document, String baseUrl) {
    final fallback = Uri.tryParse(baseUrl) ?? Uri();
    final baseHref = document.querySelector('base[href]')?.attributes['href'];
    if (baseHref == null || baseHref.isEmpty) return fallback;
    final resolved = Uri.tryParse(baseHref);
    if (resolved == null || !resolved.hasScheme) return fallback;
    return resolved;
  }

  static dom.Element? _selectMain(dom.Document document) {
    var best = _firstWithEnoughText(document, 120);
    final seen = <dom.Element>{};
    for (final selector in _contentSelectors) {
      for (final element in document.querySelectorAll(selector)) {
        if (!seen.add(element)) continue;
        final score = _score(element);
        final bestScore = best == null ? 0.0 : _score(best);
        if (score > bestScore) best = element;
      }
    }
    if (best != null) return best;
    final body = document.body;
    if (body != null && body.text.trim().length > 120) return body;
    return null;
  }

  static dom.Element? _firstWithEnoughText(dom.Document document, int length) {
    for (final selector in _contentSelectors) {
      final element = document.querySelector(selector);
      if (element != null && element.text.trim().length >= length) {
        return element;
      }
    }
    return null;
  }

  static double _score(dom.Element element) {
    final text = element.text.trim();
    if (text.length < 60) return 0;
    final paragraphs = element.querySelectorAll('p').length;
    var linkChars = 0;
    for (final link in element.querySelectorAll('a')) {
      linkChars += link.text.length;
    }
    final linkDensity = linkChars / text.length;
    final tagBonus = switch (element.localName) {
      'article' => 400,
      'main' => 250,
      _ => 0,
    };
    return text.length +
        (paragraphs * 140) +
        tagBonus -
        (linkDensity * text.length * 2.5);
  }

  static void _prepareForMarkdown(dom.Element root, Uri baseUri) {
    for (final source in root.querySelectorAll('source')) {
      source.remove();
    }
    for (final image in root.querySelectorAll('img')) {
      final raw =
          image.attributes['data-src'] ??
          image.attributes['data-lazy-src'] ??
          image.attributes['data-original'] ??
          image.attributes['src'];
      if (raw == null || raw.trim().isEmpty || raw.startsWith('data:')) {
        image.remove();
        continue;
      }
      final resolved = _resolve(raw, baseUri);
      if (resolved == null) {
        image.remove();
        continue;
      }
      final width = int.tryParse(image.attributes['width'] ?? '');
      final height = int.tryParse(image.attributes['height'] ?? '');
      if ((width != null && width <= 2) || (height != null && height <= 2)) {
        image.remove();
        continue;
      }
      image.attributes
        ..['src'] = resolved
        ..remove('srcset')
        ..remove('sizes')
        ..remove('style')
        ..remove('class')
        ..remove('width')
        ..remove('height')
        ..remove('loading')
        ..remove('decoding');
    }

    for (final link in root.querySelectorAll('a')) {
      final href = link.attributes['href'];
      if (href == null || href.startsWith('#') || href.startsWith('mailto:')) {
        continue;
      }
      final resolved = _resolve(href, baseUri);
      if (resolved == null) {
        link.attributes.remove('href');
      } else {
        link.attributes['href'] = resolved;
      }
      link.attributes
        ..remove('class')
        ..remove('style')
        ..remove('target')
        ..remove('rel');
    }

    for (final element in root.querySelectorAll(
      'video, audio, object, embed, button, input, textarea, select',
    )) {
      element.remove();
    }
  }

  static String _toMarkdown(dom.Element element, String baseUrl) {
    final markdown = html2md.convert(
      element,
      imageBaseUrl: baseUrl,
      styleOptions: const {
        'headingStyle': 'atx',
        'codeBlockStyle': 'fenced',
        'bulletListMarker': '-',
      },
    );
    return _cleanMarkdown(markdown);
  }

  static String _cleanMarkdown(String markdown) {
    var text = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAllMapped(
      RegExp(r'^\[[^\]]*\]\(\s*\)\s*$', multiLine: true),
      (_) => '',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'^(advertisement|anzeige|read more|weiterlesen|share this article)$',
        caseSensitive: false,
        multiLine: true,
      ),
      (_) => '',
    );
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (text.length > _maxMarkdownChars) {
      text = '${text.substring(0, _maxMarkdownChars)}\n\n…';
    }
    return text;
  }

  static int _usableLength(String markdown) {
    return markdown
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]\([^)]*\)'), '')
        .replaceAll(RegExp(r'[#*_>`\-\s]'), '')
        .length;
  }

  static String? _resolve(String raw, Uri baseUri) {
    if (raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    final resolved = uri.hasScheme ? uri : baseUri.resolveUri(uri);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    return resolved.toString();
  }

  static String? _metaContent(dom.Document document, String selector) {
    final content = document.querySelector(selector)?.attributes['content'];
    if (content == null || content.trim().isEmpty) return null;
    return content.trim();
  }

  static String _decodeBody(http.Response response) {
    final charset = RegExp(
      r'charset\s*=\s*"?([\w-]+)',
      caseSensitive: false,
    ).firstMatch(response.headers['content-type'] ?? '')?.group(1);
    final encoding = charset == null ? null : Encoding.getByName(charset);
    if (encoding != null) {
      return encoding.decode(response.bodyBytes);
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
}
