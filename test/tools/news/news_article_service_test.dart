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

    test('removes repeated headlines, paragraphs and hero images', () {
      const paragraph =
          'A repeated introduction with enough text to identify it reliably.';
      final html =
          '''
<html><head><meta property="og:image" content="/hero.jpg?width=900"></head>
<body><article>
<h2>Example headline</h2>
<div>by Jane Doe</div><time>Nov 7, 2026</time>
<div>$paragraph</div><p>$paragraph</p>
<p>Another paragraph that is part of the article and should remain visible.</p>
<img src="/hero.jpg?width=600"><img src="/other.jpg"><img src="/other.jpg">
<ul><li></li></ul>
</article></body></html>''';
      final article = NewsArticleService.extract(
        html,
        'https://example.com/story',
        title: 'Example headline',
        author: 'Jane Doe',
      )!;
      expect(article.imageUrl, 'https://example.com/hero.jpg?width=900');
      expect(article.markdown, isNot(contains('Example headline')));
      expect(article.markdown, isNot(contains('Jane Doe')));
      expect(article.markdown, isNot(contains('Nov 7')));
      expect(paragraph.allMatches(article.markdown), hasLength(1));
      expect(article.markdown, isNot(contains('hero.jpg')));
      expect('other.jpg'.allMatches(article.markdown), hasLength(1));
    });

    test('cleans previously cached markdown without changing code blocks', () {
      const paragraph =
          'A duplicated paragraph with enough characters to detect it.';
      final result = NewsArticleService.cleanCachedMarkdown(
        '# Headline\n\nby **[Jane Doe](https://example.com/jane)**\n\n'
        '$paragraph\n\n**$paragraph**\n\n'
        '![hero](https://example.com/hero.jpg?width=300)\n\n'
        '-\n\n```\n$paragraph\n$paragraph\n```',
        title: 'Headline',
        author: 'Jane Doe',
        heroImageUrl: 'https://example.com/hero.jpg?width=800',
      );
      expect(result, isNot(contains('Headline')));
      expect(result, isNot(contains('Jane Doe')));
      expect(result, isNot(contains('hero.jpg')));
      expect(paragraph.allMatches(result), hasLength(3));
      expect(result, isNot(contains('\n-\n')));
    });

    test('uses the first article image when metadata has no image', () {
      final article = NewsArticleService.extract(
        '<html><body><article><p>A full article with enough text to be '
            'accepted by the extractor for the reader.</p>'
            '<img src="/article.jpg"></article></body></html>',
        'https://example.com/story',
      )!;
      expect(article.imageUrl, 'https://example.com/article.jpg');
      expect(article.markdown, isNot(contains('article.jpg')));
    });

    test('finds a metadata image even without a readable article body', () {
      expect(
        NewsArticleService.extractImage(
          '<html><head><meta property="og:image" content="/preview.jpg">'
              '</head><body></body></html>',
          'https://example.com/story',
        ),
        'https://example.com/preview.jpg',
      );
    });
  });
}
