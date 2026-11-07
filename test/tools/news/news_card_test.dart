import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/widgets/news_card.dart';

class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _OfflineHttpClient();
}

class _OfflineHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Network access is disabled in this test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [220.0, 320.0, 427.0, 660.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('card fits at width $width and text scale $scale', (
        tester,
      ) async {
        final previousOverrides = HttpOverrides.current;
        final offline = _OfflineHttpOverrides();
        HttpOverrides.global = offline;
        expect(HttpOverrides.current, same(offline));
        addTearDown(() => HttpOverrides.global = previousOverrides);
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const title =
            'A long headline that wraps across multiple lines on smaller screens';
        const article = NewsArticle(
          guidKey: 'item',
          sourceShortId: 'source',
          title: title,
          summary:
              'A long summary with enough words to fill several lines and test the layout.',
          link: 'https://example.invalid/story',
          imageUrl: 'https://example.invalid/image.jpg',
          publishedAt: 1,
          fetchedAt: 1,
        );
        const source = NewsSource(
          shortId: 'source',
          title: 'A very long source name that needs space to fit in the card',
          feedUrl: 'https://example.invalid/feed',
          createdAt: 1,
          updatedAt: 1,
        );
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQueryData.fromView(
                View.of(context),
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: NewsCard(article: article, source: source, onTap: _noop),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(title), findsOneWidget);

        final imageTop = tester.getTopLeft(find.byType(Image)).dy;
        final titleTop = tester.getTopLeft(find.text(title)).dy;
        if (width < 600) {
          expect(imageTop, lessThan(titleTop));
        }
      });
    }
  }
}

void _noop() {}
