import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_article_service.dart';
import 'package:tool_lab/tools/news/news_page.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_state.dart';
import 'package:tool_lab/tools/news/widgets/news_card.dart';
import 'package:tool_lab/tools/news/widgets/news_reader_page.dart';

class _NewsState extends NewsState {
  static const source = NewsSource(
    shortId: 'source',
    title: 'Source',
    feedUrl: 'https://example.invalid/feed',
    createdAt: 1,
    updatedAt: 1,
  );
  NewsArticle article = const NewsArticle(
    id: 1,
    guidKey: 'item',
    sourceShortId: 'source',
    title: 'Article title',
    link: 'https://example.invalid/article',
    publishedAt: 1,
    fetchedAt: 1,
  );

  @override
  bool get isLoading => false;
  @override
  bool get hideRead => true;
  @override
  List<NewsSource> get sources => [source];
  @override
  List<NewsArticle> get articles => [article];
  @override
  NewsSource? sourceFor(String shortId) => source;
  @override
  Future<void> init() => Completer<void>().future;
  @override
  Future<void> markRead(NewsArticle item) async {
    article = article.copyWith(readAt: 1);
    notifyListeners();
  }

  @override
  Future<ExtractedArticle> loadArticleBody(NewsArticle item) async =>
      const ExtractedArticle(
        markdown: 'Article body',
        imageUrl: null,
        title: null,
      );
}

void main() {
  testWidgets('opening an article leaves a dimmed card in the unread view', (
    tester,
  ) async {
    final state = _NewsState();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const NewsPage())],
    );
    addTearDown(router.dispose);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<NewsState>.value(
        value: state,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Article title'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsReaderPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(NewsReaderPage))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Article title'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(NewsCard),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(1));
  });
}
