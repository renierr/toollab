import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_article_service.dart';
import 'package:tool_lab/tools/news/news_page.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_state.dart';
import 'package:tool_lab/tools/news/widgets/news_card.dart';
import 'package:tool_lab/tools/news/widgets/news_reader_page.dart';
import 'package:tool_lab/tools/news/widgets/news_source_tile.dart';
import 'package:tool_lab/widgets/focus_outline.dart';
import 'package:tool_lab/widgets/image_preview_dialog.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/tv_navigation_scope.dart';

class _AppState extends ChangeNotifier implements AppState {
  @override
  bool get tvMode => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _source = NewsSource(
  shortId: 'source',
  title: 'Source',
  feedUrl: 'https://example.invalid/feed',
  createdAt: 1,
  updatedAt: 1,
);

NewsArticle _article(int index) => NewsArticle(
  id: index,
  guidKey: 'key$index',
  sourceShortId: 'source',
  title: 'Article $index',
  summary: 'Summary $index',
  link: 'https://example.invalid/$index',
  imageUrl: 'https://example.invalid/$index.jpg',
  publishedAt: 1,
  fetchedAt: 1,
);

class _NewsState extends NewsState {
  @override
  bool get isLoading => false;
  @override
  List<NewsSource> get sources => const [_source];
  @override
  List<NewsArticle> get articles => [for (var i = 0; i < 8; i++) _article(i)];
  @override
  NewsSource? sourceFor(String shortId) => _source;
  @override
  Future<void> init() => Completer<void>().future;
  @override
  Future<void> markRead(NewsArticle article, {bool immediate = false}) async {}
  @override
  void prefetchArticleImage(NewsArticle article) {}
  @override
  Future<ExtractedArticle> loadArticleBody(NewsArticle article) async =>
      const ExtractedArticle(
        markdown:
            'Text with [a link](https://example.invalid/linked).\n\n'
            '![Chart](https://example.invalid/chart.png)',
        imageUrl: null,
        title: null,
      );
}

Future<void> _pumpTv(WidgetTester tester, NewsState state, Widget home) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => home)],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => _AppState()),
        ChangeNotifierProvider<NewsState>.value(value: state),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            TvNavigationScope(enabled: true, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _focusInside(WidgetTester tester, Finder finder) {
  final target = tester.element(finder);
  var inside = false;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    inside = e == target;
    return !inside;
  });
  return inside;
}

Finder _card(int index) => find.ancestor(
  of: find.text('Article $index'),
  matching: find.byType(NewsCard),
);

void main() {
  testWidgets('TV: opening News focuses the first article, framed by its '
      'own ring', (tester) async {
    final state = _NewsState();
    addTearDown(state.dispose);
    await _pumpTv(tester, state, const NewsPage());

    expect(_focusInside(tester, _card(0)), isTrue);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<FocusOutline>(), isNotNull);
  });

  testWidgets('TV: one Up returns from the first article to the source chips', (
    tester,
  ) async {
    final state = _NewsState();
    addTearDown(state.dispose);
    await _pumpTv(tester, state, const NewsPage());

    final chip = find.byType(ChoiceChip).first;
    Focus.of(
      tester.element(
        find.descendant(of: chip, matching: find.textContaining('All')),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    expect(_focusInside(tester, chip), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusInside(tester, _card(0)), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusInside(tester, chip), isTrue);
  });

  testWidgets('TV: holding OK on an article copies its image', (tester) async {
    final state = _NewsState();
    addTearDown(state.dispose);
    await _pumpTv(tester, state, const NewsPage());
    expect(_focusInside(tester, _card(0)), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Could not copy the image.'), findsOneWidget);
    expect(find.byType(NewsReaderPage), findsNothing);
  });

  testWidgets('TV: a source row is one stop and Down skips its controls', (
    tester,
  ) async {
    final state = _NewsState();
    addTearDown(state.dispose);
    final sources = [
      for (final id in ['a', 'b'])
        NewsSource(
          shortId: id,
          title: 'Feed $id',
          feedUrl: 'https://example.invalid/$id',
          createdAt: 1,
          updatedAt: 1,
        ),
    ];
    await _pumpTv(
      tester,
      state,
      Scaffold(
        body: ListView(
          children: [
            for (final source in sources)
              NewsSourceTile(
                source: source,
                unreadCount: 0,
                onEnabledChanged: (_) {},
                onEdit: () {},
                onDelete: () {},
              ),
          ],
        ),
      ),
    );

    final first = find.byType(NewsSourceTile).first;
    final second = find.byType(NewsSourceTile).last;
    Focus.of(
      tester.element(find.descendant(of: first, matching: find.text('Feed a'))),
    ).requestFocus();
    await tester.pumpAndSettle();
    final primary = FocusManager.instance.primaryFocus!;
    expect(
      primary.traversalDescendants.where((n) => n.canRequestFocus),
      isEmpty,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusInside(tester, second), isTrue);
    final context = FocusManager.instance.primaryFocus!.context!;
    expect(context.findAncestorWidgetOfExactType<Switch>(), isNull);
    expect(
      context.findAncestorWidgetOfExactType<PopupMenuButton<String>>(),
      isNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<Switch>(),
      isNotNull,
    );
  });

  testWidgets('TV: reader images and links are reachable with the remote', (
    tester,
  ) async {
    final state = _NewsState();
    addTearDown(state.dispose);
    await _pumpTv(
      tester,
      state,
      NewsReaderPage(article: _article(0), source: _source),
    );

    FocusNode focusIn(Finder outline) =>
        FocusManager.instance.rootScope.traversalDescendants.firstWhere((node) {
          if (!node.canRequestFocus || node.context == null) return false;
          var inside = false;
          node.context!.visitAncestorElements((e) {
            inside = e == tester.element(outline);
            return !inside;
          });
          return inside;
        });
    Finder outlineOf(Finder image) =>
        find.ancestor(of: image, matching: find.byType(FocusOutline));

    focusIn(outlineOf(find.byType(Image).first)).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewDialog), findsOneWidget);
    // The preview loads the full image, which the test HTTP client refuses.
    tester.takeException();
    Navigator.of(tester.element(find.byType(ImagePreviewDialog))).pop();
    await tester.pumpAndSettle();

    final page = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    final chart = find.descendant(
      of: find.byType(MarkdownView),
      matching: find.byType(Image),
    );
    await tester.scrollUntilVisible(chart, 200, scrollable: page);
    focusIn(outlineOf(chart)).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewDialog), findsOneWidget);
    tester.takeException();
    Navigator.of(tester.element(find.byType(ImagePreviewDialog))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('https://example.invalid/linked'),
      200,
      scrollable: page,
    );
    expect(find.text('https://example.invalid/linked'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('https://example.invalid/linked'),
        matching: find.byWidgetPredicate(
          (w) => w is ListTile && w.onTap != null,
        ),
      ),
      findsOneWidget,
    );
  });
}
