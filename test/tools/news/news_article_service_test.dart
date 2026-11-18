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
      const html =
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

    test('extracts direct video URLs but not embeds or unsafe URLs', () {
      final article = NewsArticleService.extract(
        '<html><body><article>'
            '<p>A paragraph of article text long enough for the reader to use.</p>'
            '<video src="/one.mp4"></video>'
            '<video><source src="//cdn.example.com/two.webm" type="video/webm">'
            '<source src="/alternate.mp4"></video>'
            '<video src="javascript:alert(1)"></video>'
            '<video src="/one.mp4"></video>'
            '<iframe src="https://www.youtube.com/embed/example"></iframe>'
            '</article></body></html>',
        'https://example.com/story',
      )!;
      expect(article.videoUrls, [
        'https://example.com/one.mp4',
        'https://cdn.example.com/two.webm',
      ]);
      expect(article.markdown, isNot(contains('youtube')));
    });

    test('accepts a video-only article', () {
      final article = NewsArticleService.extract(
        '<html><body><article><video src="/clip.mp4"></video>'
            '</article></body></html>',
        'https://example.com/story',
      );
      expect(article?.videoUrls, ['https://example.com/clip.mp4']);
    });

    test('keeps an article whose class only contains a junk word', () {
      final article = NewsArticleService.extract(
        '<html><body><article class="node node--promoted">'
            '<p>${'Body text of the promoted story. ' * 5}</p></article>'
            '<div class="related-posts"><p>Other story</p></div>'
            '<div class="shareBar">Share</div></body></html>',
        'https://example.com/story',
      )!;
      expect(article.markdown, contains('promoted story'));
      expect(article.markdown, isNot(contains('Other story')));
      expect(article.markdown, isNot(contains('Share')));
    });

    test('keeps absolute image URLs and drops crop variants of the hero', () {
      final article = NewsArticleService.extract(
        '<html><body><article><p>${'Some story text here. ' * 5}</p>'
            '<img src="https://cdn.example.com/a/hero.jpg?crop=0,10,100,80&w=2400">'
            '<a href="https://cdn.example.com/a/photo.jpg?w=2400">'
            '<img src="https://cdn.example.com/a/photo.jpg?w=1200"></a>'
            '<img src="https://cdn.example.com/a/author.jpg?w=96">'
            '<figure><img src="https://cdn.example.com/a/photo-1200x630.jpg">'
            '<figcaption><span>Caption.</span><span>Credit</span></figcaption>'
            '</figure></article></body></html>',
        'https://example.com/story',
        heroImageUrl: 'https://cdn.example.com/a/hero.jpg?crop=0,0,100,100',
      )!;
      final markdown = article.markdown;
      expect(markdown, isNot(contains('hero.jpg')));
      expect(markdown, isNot(contains('author.jpg')));
      expect('photo'.allMatches(markdown), hasLength(1));
      expect(markdown, contains('](https://cdn.example.com/a/photo.jpg'));
      expect(markdown, isNot(contains('[![')));
      expect(markdown, contains('_Caption. Credit_'));
    });

    test('drops size variants encoded in the file name or path', () {
      const cdn = 'https://cdn.example.com/images';
      final article = NewsArticleService.extract(
        '<html><body><article><p>${'Some story text here. ' * 5}</p>'
            '<img src="$cdn/9d2d-56a6_w960_r1.5_fpx51_fpy40.jpg">'
            '<img src="$cdn/9d2d-56a6_w520_r1.33_fpx51_fpy40.jpg">'
            '<img src="$cdn/w_640,h_360,c_fill/photo.jpg">'
            '<img src="$cdn/w_1280,c_fill/photo.jpg">'
            '<img src="$cdn/1.jpg"><img src="$cdn/2.jpg">'
            '</article></body></html>',
        'https://example.com/story',
        heroImageUrl: '$cdn/9d2d-56a6_w1200_r1.778_fpx51_fpy40.jpg',
      )!;
      final markdown = article.markdown;
      expect(markdown, isNot(contains('9d2d-56a6')));
      expect('photo.jpg'.allMatches(markdown), hasLength(1));
      expect(markdown, contains('$cdn/1.jpg'));
      expect(markdown, contains('$cdn/2.jpg'));
    });

    test('drops related teasers, print-only copies and templates', () {
      final article = NewsArticleService.extract(
        '<html><body><article>'
            '<div class="hidden print:block">Printed for personal use.</div>'
            '<p>${'Some story text here. ' * 5}</p>'
            '<section data-area="related_articles"><ul><li>'
            '<a href="/other">Other story</a></li></ul></section>'
            '<a href="https://google.com/preferences/source?q=x">Prefer</a>'
            '<h2> </h2><template><p>__proto_headline__</p></template>'
            '</article></body></html>',
        'https://example.com/story',
      )!;
      final markdown = article.markdown;
      expect(markdown, contains('Some story text'));
      expect(markdown, isNot(contains('Printed')));
      expect(markdown, isNot(contains('Other story')));
      expect(markdown, isNot(contains('Prefer')));
      expect(markdown, isNot(contains('proto')));
      expect(markdown, isNot(contains('##')));
    });

    test('rejects a bot check page', () {
      final article = NewsArticleService.extract(
        '<html><head><title>Just a moment...</title></head><body><main>'
            '<h1>Automated bot check in progress</h1><p>This should only take '
            'a few seconds. If you have issues, please contact us.</p>'
            '</main></body></html>',
        'https://example.com/story',
      );
      expect(article, isNull);
    });

    test(
      'repairs image URLs prefixed with the page URL in cached markdown',
      () {
        final result = NewsArticleService.cleanCachedMarkdown(
          '![x](https://example.com/story/https://cdn.example.com/a.jpg)',
          title: 'Headline',
        );
        expect(result, '![x](https://cdn.example.com/a.jpg)');
      },
    );
  });
}
