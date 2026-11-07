import 'dart:convert';

import 'package:crypto/crypto.dart';

class NewsCatalogCategory {
  final String id;

  const NewsCatalogCategory(this.id);
}

class NewsCatalogSource {
  final String title;
  final String feedUrl;
  final String siteUrl;
  final bool enabledByDefault;

  const NewsCatalogSource({
    required this.title,
    required this.feedUrl,
    this.siteUrl = '',
    this.enabledByDefault = true,
  });
}

/// Curated, verified feeds. Categories are ids so the UI can localize them;
/// source names stay as the publisher writes them.
class NewsCatalog {
  static const String customCategory = 'custom';

  static const List<NewsCatalogCategory> categories = [
    NewsCatalogCategory('top'),
    NewsCatalogCategory('world'),
    NewsCatalogCategory('germany'),
    NewsCatalogCategory('technology'),
    NewsCatalogCategory('business'),
    NewsCatalogCategory('science'),
    NewsCatalogCategory('sport'),
    NewsCatalogCategory('culture'),
    NewsCatalogCategory(customCategory),
  ];

  static const Map<String, List<NewsCatalogSource>> byCategory = {
    'top': [
      NewsCatalogSource(
        title: 'BBC Top Stories',
        feedUrl: 'https://feeds.bbci.co.uk/news/rss.xml',
        siteUrl: 'https://www.bbc.com/news',
      ),
      NewsCatalogSource(
        title: 'NPR News',
        feedUrl: 'https://feeds.npr.org/1001/rss.xml',
        siteUrl: 'https://www.npr.org',
      ),
      NewsCatalogSource(
        title: 'Al Jazeera',
        feedUrl: 'https://www.aljazeera.com/xml/rss/all.xml',
        siteUrl: 'https://www.aljazeera.com',
      ),
      NewsCatalogSource(
        title: 'Deutsche Welle',
        feedUrl: 'https://rss.dw.com/rdf/rss-en-all',
        siteUrl: 'https://www.dw.com',
      ),
      NewsCatalogSource(
        title: 'France 24',
        feedUrl: 'https://www.france24.com/en/rss',
        siteUrl: 'https://www.france24.com/en',
      ),
      NewsCatalogSource(
        title: 'New York Times World',
        feedUrl: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
        siteUrl: 'https://www.nytimes.com/section/world',
      ),
    ],
    'world': [
      NewsCatalogSource(
        title: 'BBC World',
        feedUrl: 'https://feeds.bbci.co.uk/news/world/rss.xml',
        siteUrl: 'https://www.bbc.com/news/world',
      ),
      NewsCatalogSource(
        title: 'The Guardian World',
        feedUrl: 'https://www.theguardian.com/world/rss',
        siteUrl: 'https://www.theguardian.com/world',
      ),
    ],
    'germany': [
      NewsCatalogSource(
        title: 'tagesschau',
        feedUrl: 'https://www.tagesschau.de/xml/rss2/',
        siteUrl: 'https://www.tagesschau.de',
      ),
      NewsCatalogSource(
        title: 'SPIEGEL',
        feedUrl: 'https://www.spiegel.de/schlagzeilen/index.rss',
        siteUrl: 'https://www.spiegel.de',
      ),
      NewsCatalogSource(
        title: 'ZEIT ONLINE',
        feedUrl: 'https://newsfeed.zeit.de/index',
        siteUrl: 'https://www.zeit.de',
      ),
    ],
    'technology': [
      NewsCatalogSource(
        title: 'Ars Technica',
        feedUrl: 'https://feeds.arstechnica.com/arstechnica/index',
        siteUrl: 'https://arstechnica.com',
      ),
      NewsCatalogSource(
        title: 'The Verge',
        feedUrl: 'https://www.theverge.com/rss/index.xml',
        siteUrl: 'https://www.theverge.com',
      ),
      NewsCatalogSource(
        title: 'Wired',
        feedUrl: 'https://www.wired.com/feed/rss',
        siteUrl: 'https://www.wired.com',
      ),
      NewsCatalogSource(
        title: 'TechCrunch',
        feedUrl: 'https://techcrunch.com/feed/',
        siteUrl: 'https://techcrunch.com',
      ),
      NewsCatalogSource(
        title: 'Hacker News',
        feedUrl: 'https://hnrss.org/frontpage',
        siteUrl: 'https://news.ycombinator.com',
      ),
      NewsCatalogSource(
        title: 'heise online',
        feedUrl: 'https://www.heise.de/rss/heise-atom.xml',
        siteUrl: 'https://www.heise.de',
      ),
      NewsCatalogSource(
        title: 'BBC Technology',
        feedUrl: 'https://feeds.bbci.co.uk/news/technology/rss.xml',
        siteUrl: 'https://www.bbc.com/news/technology',
      ),
      NewsCatalogSource(
        title: 'The Guardian Technology',
        feedUrl: 'https://www.theguardian.com/uk/technology/rss',
        siteUrl: 'https://www.theguardian.com/uk/technology',
      ),
      NewsCatalogSource(
        title: 'New York Times Technology',
        feedUrl: 'https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml',
        siteUrl: 'https://www.nytimes.com/section/technology',
      ),
    ],
    'business': [
      NewsCatalogSource(
        title: 'BBC Business',
        feedUrl: 'https://feeds.bbci.co.uk/news/business/rss.xml',
        siteUrl: 'https://www.bbc.com/news/business',
      ),
      NewsCatalogSource(
        title: 'The Guardian Business',
        feedUrl: 'https://www.theguardian.com/business/rss',
        siteUrl: 'https://www.theguardian.com/business',
      ),
      NewsCatalogSource(
        title: 'Financial Times',
        feedUrl: 'https://www.ft.com/rss/home',
        siteUrl: 'https://www.ft.com',
      ),
      NewsCatalogSource(
        title: 'CNBC',
        feedUrl: 'https://www.cnbc.com/id/100003114/device/rss/rss.html',
        siteUrl: 'https://www.cnbc.com',
      ),
    ],
    'science': [
      NewsCatalogSource(
        title: 'NASA',
        feedUrl: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
        siteUrl: 'https://www.nasa.gov',
      ),
      NewsCatalogSource(
        title: 'ScienceDaily',
        feedUrl: 'https://www.sciencedaily.com/rss/all.xml',
        siteUrl: 'https://www.sciencedaily.com',
      ),
      NewsCatalogSource(
        title: 'Nature',
        feedUrl: 'https://www.nature.com/nature.rss',
        siteUrl: 'https://www.nature.com',
      ),
      NewsCatalogSource(
        title: 'The Guardian Science',
        feedUrl: 'https://www.theguardian.com/science/rss',
        siteUrl: 'https://www.theguardian.com/science',
      ),
    ],
    'sport': [
      NewsCatalogSource(
        title: 'BBC Sport',
        feedUrl: 'https://feeds.bbci.co.uk/sport/rss.xml',
        siteUrl: 'https://www.bbc.com/sport',
      ),
      NewsCatalogSource(
        title: 'The Guardian Sport',
        feedUrl: 'https://www.theguardian.com/sport/rss',
        siteUrl: 'https://www.theguardian.com/sport',
      ),
      NewsCatalogSource(
        title: 'Sky Sports',
        feedUrl: 'https://www.skysports.com/rss/12040',
        siteUrl: 'https://www.skysports.com',
      ),
    ],
    'culture': [
      NewsCatalogSource(
        title: 'The Guardian Culture',
        feedUrl: 'https://www.theguardian.com/culture/rss',
        siteUrl: 'https://www.theguardian.com/culture',
      ),
      NewsCatalogSource(
        title: 'BBC Entertainment & Arts',
        feedUrl: 'https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml',
        siteUrl: 'https://www.bbc.com/news/entertainment_and_arts',
      ),
      NewsCatalogSource(
        title: 'Variety',
        feedUrl: 'https://variety.com/feed/',
        siteUrl: 'https://variety.com',
      ),
      NewsCatalogSource(
        title: 'Rolling Stone',
        feedUrl: 'https://www.rollingstone.com/feed/',
        siteUrl: 'https://www.rollingstone.com',
      ),
    ],
  };

  /// Preloaded on first run so the tool has a timeline before setup. Stable ids
  /// let another device's seed merge with these instead of duplicating them.
  static const List<NewsCatalogSource> seeds = [
    NewsCatalogSource(
      title: 'BBC Top Stories',
      feedUrl: 'https://feeds.bbci.co.uk/news/rss.xml',
      siteUrl: 'https://www.bbc.com/news',
    ),
    NewsCatalogSource(
      title: 'NPR News',
      feedUrl: 'https://feeds.npr.org/1001/rss.xml',
      siteUrl: 'https://www.npr.org',
    ),
    NewsCatalogSource(
      title: 'Al Jazeera',
      feedUrl: 'https://www.aljazeera.com/xml/rss/all.xml',
      siteUrl: 'https://www.aljazeera.com',
      enabledByDefault: false,
    ),
    NewsCatalogSource(
      title: 'The Guardian World',
      feedUrl: 'https://www.theguardian.com/world/rss',
      siteUrl: 'https://www.theguardian.com/world',
    ),
  ];

  static String? categoryForFeed(String feedUrl) {
    for (final entry in byCategory.entries) {
      for (final source in entry.value) {
        if (source.feedUrl == feedUrl) return entry.key;
      }
    }
    return null;
  }

  /// Deterministic source id: adding the same feed on two devices produces the
  /// same id, so sync sees one source instead of a duplicate.
  static String shortIdForFeed(String feedUrl) {
    final digest = sha1.convert(utf8.encode(feedUrl.trim()));
    return 'N${digest.toString().substring(0, 11).toUpperCase()}';
  }
}
