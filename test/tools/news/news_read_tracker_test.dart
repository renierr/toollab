import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/widgets/news_card.dart';
import 'package:tool_lab/tools/news/widgets/news_list.dart';
import 'package:tool_lab/tools/news/widgets/news_read_tracker.dart';

void main() {
  testWidgets('marks visible cards only after scrolling past them', (
    tester,
  ) async {
    final seen = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) => NewsReadTracker(
              article: NewsArticle(
                id: index,
                guidKey: '$index',
                sourceShortId: 'source',
                title: '$index',
                link: '',
                publishedAt: 0,
                fetchedAt: 0,
              ),
              enabled: true,
              onSeen: () => seen.add(index),
              child: SizedBox(height: 200, child: Text('Article $index')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(seen, isEmpty);

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(seen, contains(0));
    expect(seen, isNot(contains(3)));
  });

  testWidgets('marks visible cards even when a fast jump disposes them', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final seen = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 30,
            itemBuilder: (context, index) => NewsReadTracker(
              article: NewsArticle(
                id: index,
                guidKey: '$index',
                sourceShortId: 'source',
                title: '$index',
                link: '',
                publishedAt: 0,
                fetchedAt: 0,
              ),
              enabled: true,
              onSeen: () => seen.add(index),
              child: SizedBox(height: 200, child: Text('Article $index')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.jumpTo(1400);
    await tester.pumpAndSettle();
    expect(seen, containsAll([0, 1, 2]));
    expect(seen, isNot(contains(3)));
    expect(seen.toSet(), hasLength(seen.length));
  });

  testWidgets('reports visible cards for previews even with scroll-read off', (
    tester,
  ) async {
    final visible = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) => NewsReadTracker(
              article: NewsArticle(
                id: index,
                guidKey: '$index',
                sourceShortId: 'source',
                title: '$index',
                link: '',
                publishedAt: 0,
                fetchedAt: 0,
              ),
              enabled: false,
              onSeen: () => fail('Scroll-read is disabled'),
              onVisible: () => visible.add(index),
              child: SizedBox(height: 200, child: Text('Article $index')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(visible, containsAll([0, 1, 2]));
    expect(visible, isNot(contains(3)));
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(visible, contains(3));
  });

  testWidgets('scrolling a timeline dims read cards without removing them', (
    tester,
  ) async {
    var articles = [
      for (var index = 0; index < 30; index++)
        NewsArticle(
          id: index,
          guidKey: '$index',
          sourceShortId: 'source',
          title: 'Article $index',
          summary: 'A short article summary.',
          link: '',
          publishedAt: 1,
          fetchedAt: 1,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NewsList(
              articles: articles,
              sourceResolver: (_) => null,
              markReadOnScroll: true,
              empty: const SizedBox.shrink(),
              onRefresh: () async {},
              onOpen: (_) {},
              onSeen: (seen) => setState(() {
                articles = [
                  for (final article in articles)
                    if (article.id == seen.id)
                      article.copyWith(readAt: 1)
                    else
                      article,
                ];
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(articles.first.isRead, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, 450));
    await tester.pumpAndSettle();
    final card = find.ancestor(
      of: find.text('Article 0'),
      matching: find.byType(NewsCard),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(of: card, matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(1));
    expect(articles, hasLength(30));
  });
}
