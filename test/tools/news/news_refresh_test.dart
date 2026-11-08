import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_page.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_state.dart';
import 'package:tool_lab/tools/news/widgets/news_list.dart';

class _AppState extends ChangeNotifier implements AppState {
  @override
  bool syncsTool(String toolId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NewsState extends NewsState {
  int refreshes = 0;
  Completer<void>? refreshCompletion;
  @override
  bool get isLoading => false;
  @override
  bool get markReadOnScroll => false;
  @override
  List<NewsSource> get sources => const [];
  @override
  List<NewsArticle> get articles => [
    for (var i = 0; i < 30; i++)
      NewsArticle(
        id: i,
        guidKey: '$i',
        sourceShortId: 'source',
        title: 'Article $i',
        link: '',
        publishedAt: 1,
        fetchedAt: 1,
      ),
  ];
  @override
  Future<void> init() => Completer<void>().future;
  @override
  void prefetchArticleImage(NewsArticle article) {}
  @override
  Future<void> refresh({List<NewsSource>? only}) async {
    refreshes++;
    await refreshCompletion?.future;
  }
}

void main() {
  testWidgets('toolbar and bottom pull refresh return to the top', (
    tester,
  ) async {
    final state = _NewsState();
    final appState = _AppState();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const NewsPage())],
    );
    addTearDown(state.dispose);
    addTearDown(appState.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NewsState>.value(value: state),
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(NewsList),
      matching: find.byType(ListView),
    );
    final controller = tester.widget<ListView>(list).controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    state.refreshCompletion = Completer<void>();
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    state.refreshCompletion!.complete();
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(state.refreshes, 1);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    state.refreshCompletion = null;
    await tester.drag(list, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(state.refreshes, 2);
    expect(controller.offset, 0);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(state.refreshes, 2);

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 250));
    await tester.pumpAndSettle();
    expect(state.refreshes, 3);
  });
}
