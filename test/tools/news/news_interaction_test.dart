import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_article_service.dart';
import 'package:tool_lab/tools/news/news_page.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_state.dart';
import 'package:tool_lab/tools/news/widgets/news_card.dart';
import 'package:tool_lab/tools/news/widgets/news_reader_page.dart';

class _AppState extends ChangeNotifier implements AppState {
  int syncCalls = 0;

  @override
  bool syncsTool(String toolId) => true;

  @override
  Future<Map<String, int>?> syncWithBackend(
    List<SyncDelegate> delegates,
  ) async {
    syncCalls++;
    return {'pulled': 0, 'pushed': 0, 'deleted': 0};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NewsState extends NewsState {
  int _readGeneration = 0;
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
  int get readGeneration => _readGeneration;
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
  Future<void> markRead(NewsArticle item, {bool immediate = false}) async {
    article = article.copyWith(readAt: 1);
    _readGeneration++;
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
  testWidgets('opening an article dims its card and syncs on return', (
    tester,
  ) async {
    final state = _NewsState();
    final appState = _AppState();
    addTearDown(appState.dispose);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const NewsPage())],
    );
    addTearDown(router.dispose);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<NewsState>.value(
        value: state,
        child: ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
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
    expect(appState.syncCalls, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(appState.syncCalls, 1);
    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(NewsCard),
        matching: find.text('Article title'),
      ),
    );
    expect(title.style!.color!.a, lessThan(1));
  });
}
