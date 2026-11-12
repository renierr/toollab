import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/widgets/news_list.dart';
import 'package:tool_lab/tools/news/widgets/news_read_tracker.dart';

void main() {
  testWidgets('arrow keys centre the next card and reach the refresh footer', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final seen = <int>[];
    var refreshes = 0;
    var rights = 0;
    final articles = [
      for (var index = 0; index < 12; index++)
        NewsArticle(
          id: index,
          guidKey: 'key$index',
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
            controller: controller,
            articles: articles,
            sourceResolver: (_) => null,
            markReadOnScroll: true,
            empty: const SizedBox.shrink(),
            onRefresh: () async {
              refreshes++;
              controller.jumpTo(0);
            },
            onOpen: (_) {},
            onSeen: (article) => seen.add(article.id!),
            onRight: () => rights++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FocusNode cardNode(int index) =>
        Focus.of(tester.element(find.text('Article $index')));

    cardNode(0).requestFocus();
    await tester.pump();
    for (var index = 1; index <= 5; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, cardNode(index));
    }
    final viewport = tester.getRect(find.byType(ListView));
    final card = tester.getRect(
      find.ancestor(
        of: find.text('Article 5'),
        matching: find.byType(NewsReadTracker),
      ),
    );
    expect(card.center.dy, moreOrLessEquals(viewport.center.dy, epsilon: 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, cardNode(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(rights, 1);

    for (var index = 5; index <= 12; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final footer = tester.widget<ButtonStyleButton>(
      find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(FocusManager.instance.primaryFocus, footer.focusNode);
    expect(find.text('Mark as read and refresh'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(seen, contains(11));
    expect(controller.offset, 0);
    expect(FocusManager.instance.primaryFocus, cardNode(0));
  });
}
