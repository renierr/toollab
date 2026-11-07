import 'package:flutter/gestures.dart';
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

  testWidgets('marks the last visible articles after reaching the end', (
    tester,
  ) async {
    final seen = <int>[];
    final articles = [
      for (var index = 0; index < 12; index++)
        NewsArticle(
          id: index,
          guidKey: '$index',
          sourceShortId: 'source',
          title: 'Article $index',
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
          body: NewsList(
            articles: articles,
            sourceResolver: (_) => null,
            markReadOnScroll: true,
            empty: const SizedBox.shrink(),
            onRefresh: () async {},
            onOpen: (_) {},
            onSeen: (article) => seen.add(article.id!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(seen, isEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(seen, contains(11));
    expect(seen.toSet(), hasLength(seen.length));
  });

  testWidgets('a short timeline waits for a deliberate scroll to its end', (
    tester,
  ) async {
    final seen = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NewsList(
            articles: const [
              NewsArticle(
                id: 1,
                guidKey: 'short',
                sourceShortId: 'source',
                title: 'Short article',
                link: '',
                publishedAt: 1,
                fetchedAt: 1,
              ),
            ],
            sourceResolver: (_) => null,
            markReadOnScroll: true,
            empty: const SizedBox.shrink(),
            onRefresh: () async {},
            onOpen: (_) {},
            onSeen: (article) => seen.add(article.id!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(seen, isEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(seen, [1]);
  });

  testWidgets('a mouse wheel can mark the last card at the end', (
    tester,
  ) async {
    final seen = <int>[];
    final articles = [
      for (var index = 0; index < 12; index++)
        NewsArticle(
          id: index,
          guidKey: 'wheel$index',
          sourceShortId: 'source',
          title: 'Article $index',
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
          body: NewsList(
            articles: articles,
            sourceResolver: (_) => null,
            markReadOnScroll: true,
            empty: const SizedBox.shrink(),
            onRefresh: () async {},
            onOpen: (_) {},
            onSeen: (article) => seen.add(article.id!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(ListView)),
        scrollDelta: const Offset(0, 5000),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(seen, contains(11));
  });

  testWidgets(
    'a mouse wheel works on a short timeline and respects the switch',
    (tester) async {
      final seen = <int>[];
      var enabled = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return NewsList(
                  articles: const [
                    NewsArticle(
                      id: 1,
                      guidKey: 'short-wheel',
                      sourceShortId: 'source',
                      title: 'Short article',
                      link: '',
                      publishedAt: 1,
                      fetchedAt: 1,
                    ),
                  ],
                  sourceResolver: (_) => null,
                  markReadOnScroll: enabled,
                  empty: const SizedBox.shrink(),
                  onRefresh: () async {},
                  onOpen: (_) {},
                  onSeen: (article) => seen.add(article.id!),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> scrollWheel() async {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(find.byType(ListView)),
            scrollDelta: const Offset(0, 100),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }

      await scrollWheel();
      expect(seen, isEmpty);
      update(() => enabled = true);
      await tester.pump();
      await scrollWheel();
      expect(seen, [1]);
    },
  );

  testWidgets('end signal skips partially visible normal cards', (
    tester,
  ) async {
    final controller = ScrollController();
    final reachedEnd = ValueNotifier(0);
    addTearDown(controller.dispose);
    addTearDown(reachedEnd.dispose);
    final seen = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 300,
              child: ListView.builder(
                controller: controller,
                itemCount: 3,
                itemBuilder: (_, index) => NewsReadTracker(
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
                  reachedEnd: reachedEnd,
                  onSeen: () => seen.add(index),
                  child: const SizedBox(height: 200),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.jumpTo(100);
    await tester.pump();
    reachedEnd.value++;
    await tester.pump();
    expect(seen, [1]);
  });

  testWidgets('end signal handles a card taller than the viewport', (
    tester,
  ) async {
    final controller = ScrollController();
    final reachedEnd = ValueNotifier(0);
    addTearDown(controller.dispose);
    addTearDown(reachedEnd.dispose);
    var seen = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 300,
              child: ListView(
                controller: controller,
                children: [
                  NewsReadTracker(
                    article: const NewsArticle(
                      id: 1,
                      guidKey: 'tall',
                      sourceShortId: 'source',
                      title: 'Tall',
                      link: '',
                      publishedAt: 0,
                      fetchedAt: 0,
                    ),
                    enabled: true,
                    reachedEnd: reachedEnd,
                    onSeen: () => seen++,
                    child: const SizedBox(height: 900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    reachedEnd.value++;
    await tester.pump();
    expect(seen, 1);
  });
}
