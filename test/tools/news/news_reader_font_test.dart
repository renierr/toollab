import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_article_service.dart';
import 'package:tool_lab/tools/news/news_state.dart';
import 'package:tool_lab/tools/news/widgets/news_reader_page.dart';
import 'package:tool_lab/widgets/markdown_view.dart';

class _NewsState extends NewsState {
  _NewsState({this.fail = false});

  final bool fail;
  int _fontPercent = 100;

  @override
  int get readerFontPercent => _fontPercent;

  @override
  Future<void> setReaderFontPercent(int value) async {
    _fontPercent = value.clamp(
      NewsState.minReaderFontPercent,
      NewsState.maxReaderFontPercent,
    );
    notifyListeners();
  }

  @override
  Future<ExtractedArticle> loadArticleBody(NewsArticle article) async {
    if (fail) throw const ArticleExtractException('offline');
    return const ExtractedArticle(
      markdown: 'Readable article text.',
      imageUrl: null,
      title: null,
    );
  }
}

const _article = NewsArticle(
  guidKey: 'item',
  sourceShortId: 'source',
  title: 'Article title',
  summary: 'Article summary.',
  link: 'https://example.invalid/article',
  publishedAt: 1,
  fetchedAt: 1,
);

void main() {
  for (final fail in [false, true]) {
    testWidgets('font controls scale ${fail ? 'fallback' : 'article'} text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _NewsState(fail: fail);
      addTearDown(state.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<NewsState>.value(
          value: state,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQueryData.fromView(
                View.of(context),
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const NewsReaderPage(article: _article),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final titleFinder = find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'Article title',
      );
      final title = tester.widget<SelectableText>(titleFinder);
      final originalTitleSize = title.style!.fontSize!;
      if (!fail) {
        expect(
          tester.widget<MarkdownView>(find.byType(MarkdownView)).scale,
          1.5,
        );
      }

      await tester.tap(find.byTooltip('Increase text size'));
      await tester.pumpAndSettle();
      expect(state.readerFontPercent, 110);
      expect(
        tester.widget<SelectableText>(titleFinder).style!.fontSize!,
        closeTo(originalTitleSize * 1.1, 0.001),
      );
      if (fail) {
        expect(
          tester.widget<Text>(find.text('Article summary.')).style!.fontSize,
          closeTo(17.6, 0.001),
        );
      } else {
        expect(
          tester.widget<MarkdownView>(find.byType(MarkdownView)).scale,
          closeTo(1.65, 0.001),
        );
        final bodyText = tester.widget<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.textSpan?.toPlainText() == 'Readable article text.',
          ),
        );
        expect(bodyText.textScaler!.scale(16), closeTo(26.4, 0.001));
      }
      await tester.tap(find.byTooltip('Decrease text size'));
      await tester.pumpAndSettle();
      expect(state.readerFontPercent, 100);
      await state.setReaderFontPercent(NewsState.maxReaderFontPercent);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Increase text size'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await state.setReaderFontPercent(NewsState.minReaderFontPercent);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Decrease text size'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
