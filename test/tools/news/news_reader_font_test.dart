import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_article_service.dart';
import 'package:tool_lab/tools/news/news_error.dart';
import 'package:tool_lab/tools/news/news_state.dart';
import 'package:tool_lab/tools/news/widgets/news_reader_page.dart';
import 'package:tool_lab/widgets/markdown_view.dart';

class _NewsState extends NewsState {
  _NewsState({this.fail = false, this.videoUrls = const []});

  final bool fail;
  final List<String> videoUrls;
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
    if (fail) throw const NewsException(NewsError.unreachable);
    return ExtractedArticle(
      markdown: 'Readable article text.',
      imageUrl: null,
      title: null,
      videoUrls: videoUrls,
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
  testWidgets('reader offers direct video playback and image copying', (
    tester,
  ) async {
    final state = _NewsState(videoUrls: ['https://example.invalid/video.mp4']);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<NewsState>.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NewsReaderPage(article: _article),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Play video'), findsOneWidget);
    expect(
      tester.widget<MarkdownView>(find.byType(MarkdownView)).copyImages,
      isTrue,
    );
  });

  testWidgets('shows an error when sharing fails', (tester) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final state = _NewsState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<NewsState>.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NewsReaderPage(article: _article),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share link'));
    await tester.pump();
    expect(find.text('Could not share the link.'), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  for (final fail in [false, true]) {
    testWidgets('shares article URL from ${fail ? 'fallback' : 'reader'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      MethodCall? shareCall;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shareCall = call;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final state = _NewsState(fail: fail);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<NewsState>.value(
          value: state,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const NewsReaderPage(article: _article),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Share link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share link'));
      await tester.pumpAndSettle();
      expect(shareCall?.method, 'share');
      expect(shareCall?.arguments['text'], _article.link);
      expect(tester.takeException(), isNull);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));
  }

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.linux,
    TargetPlatform.windows,
  ]) {
    testWidgets('copies article URL on $platform', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final state = _NewsState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<NewsState>.value(
          value: state,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const NewsReaderPage(article: _article),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Share link'),
        platform == TargetPlatform.android ? findsOneWidget : findsNothing,
      );
      await tester.ensureVisible(find.text('Copy link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy link'));
      await tester.pump();
      expect(copied, _article.link);
      expect(find.text('Link copied to clipboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

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
