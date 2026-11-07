import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/news/news_article_service.dart';

void main() {
  group('NewsArticleService.extract', () {
    test('strips chrome and keeps the article body', () {
      const html = '''
<!doctype html>
<html>
<head>
  <title>Fallback title</title>
  <meta property="og:image" content="https://example.com/hero.jpg">
</head>
<body>
  <nav><a href="/">Home</a><a href="/world">World</a></nav>
  <div class="advert">Buy now</div>
  <article>
    <h1>A real story</h1>
    <p>First paragraph with a <a href="/related">link</a>.</p>
    <p>Second paragraph with an image.</p>
    <img src="/images/photo.jpg" width="800" height="450">
    <script>alert('no')</script>
  </article>
  <footer>Copyright</footer>
</body>
</html>
''';
      final article = NewsArticleService.extract(
        html,
        'https://example.com/news/story',
      );

      expect(article, isNotNull);
      final markdown = article!.markdown;
      expect(markdown, contains('A real story'));
      expect(markdown, contains('First paragraph'));
      expect(markdown, contains('https://example.com/related'));
      expect(markdown, contains('https://example.com/images/photo.jpg'));
      expect(article.imageUrl, 'https://example.com/hero.jpg');
      expect(markdown, isNot(contains('Buy now')));
      expect(markdown, isNot(contains('Copyright')));
    });

    test('returns null for a page without an article body', () {
      const html = '''
<html><body>
  <nav>Only navigation</nav>
  <div class="menu"><a href="/a">A</a><a href="/b">B</a></div>
</body></html>
''';
      final article = NewsArticleService.extract(html, 'https://example.com');
      expect(article, isNull);
    });
  });
}
