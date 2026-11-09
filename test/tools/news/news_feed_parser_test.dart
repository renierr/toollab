import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/news/news_catalog.dart';
import 'package:tool_lab/tools/news/news_error.dart';
import 'package:tool_lab/tools/news/news_feed_parser.dart';

void main() {
  group('NewsFeedParser', () {
    test('parses RSS with media and content namespaces', () {
      const rss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>Example News</title>
    <link>https://example.com</link>
    <item>
      <title>Big story &amp; more</title>
      <link>https://example.com/story</link>
      <guid>story-1</guid>
      <pubDate>Wed, 02 Oct 2024 13:00:00 GMT</pubDate>
      <description>&lt;p&gt;A short &lt;b&gt;teaser&lt;/b&gt;.&lt;/p&gt;</description>
      <content:encoded><![CDATA[<p>Full body with <img src="/photo.jpg"></p>]]></content:encoded>
      <media:thumbnail url="https://cdn.example.com/thumb.jpg" />
    </item>
  </channel>
</rss>
''';
      final feed = NewsFeedParser.parse(
        rss,
        sourceShortId: 'SRC1',
        feedUrl: 'https://example.com/feed.xml',
      );

      expect(feed.title, 'Example News');
      expect(feed.items, hasLength(1));
      final item = feed.items.first;
      expect(item.title, 'Big story & more');
      expect(item.summary, 'A short teaser.');
      expect(item.link, 'https://example.com/story');
      expect(item.imageUrl, 'https://cdn.example.com/thumb.jpg');
      expect(
        item.publishedAt,
        DateTime.utc(2024, 10, 2, 13).millisecondsSinceEpoch,
      );
      expect(item.guidKey, isNotEmpty);
    });

    test('parses Atom with relative image and alternate link', () {
      const atom = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Feed</title>
  <link href="https://atom.example.com/" rel="alternate" />
  <entry>
    <title>Atom story</title>
    <link href="/entry/1" rel="alternate" />
    <id>tag:atom.example.com,2024:1</id>
    <updated>2024-10-02T13:00:00Z</updated>
    <summary>Teaser text</summary>
    <content type="html">&lt;p&gt;Body &lt;img src="img/pic.png" /&gt;&lt;/p&gt;</content>
    <author><name>Jane Doe</name></author>
  </entry>
</feed>
''';
      final feed = NewsFeedParser.parse(
        atom,
        sourceShortId: 'SRC2',
        feedUrl: 'https://atom.example.com/feed.xml',
      );

      expect(feed.title, 'Atom Feed');
      expect(feed.siteUrl, 'https://atom.example.com/');
      final item = feed.items.first;
      expect(item.link, 'https://atom.example.com/entry/1');
      expect(item.author, 'Jane Doe');
      expect(item.imageUrl, 'https://atom.example.com/img/pic.png');
      expect(item.summary, 'Teaser text');
    });

    test('parses RFC 822 dates with timezone abbreviations', () {
      expect(
        NewsFeedParser.parseFeedDate('Wed, 02 Oct 2024 13:00:00 GMT'),
        DateTime.utc(2024, 10, 2, 13).millisecondsSinceEpoch,
      );
      expect(
        NewsFeedParser.parseFeedDate('Wed, 02 Oct 2024 09:00:00 EDT'),
        DateTime.utc(2024, 10, 2, 13).millisecondsSinceEpoch,
      );
      expect(NewsFeedParser.parseFeedDate(''), 0);
    });

    test('handles Unicode identifiers and case-sensitive feed paths', () {
      final feed = NewsFeedParser.parse(
        '<rss><channel><item><title>News</title><guid>新闻 📰</guid>'
        '<link>https://example.com/story</link></item></channel></rss>',
        sourceShortId: 'source',
        feedUrl: 'https://example.com/feed',
      );
      expect(feed.items.single.guidKey, isNotEmpty);
      expect(
        NewsCatalog.shortIdForFeed('https://example.com/Feed'),
        isNot(NewsCatalog.shortIdForFeed('https://example.com/feed')),
      );
      expect(NewsCatalog.shortIdForFeed('https://example.com/新闻'), isNotEmpty);
    });

    test('rejects a non-feed document', () {
      expect(
        () => NewsFeedParser.parse(
          '<html><body>nope</body></html>',
          sourceShortId: 'SRC',
          feedUrl: 'https://example.com',
        ),
        throwsA(
          isA<NewsException>().having(
            (e) => e.error,
            'error',
            NewsError.notAFeed,
          ),
        ),
      );
    });
  });
}
