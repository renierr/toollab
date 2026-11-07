import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/news/news_article.dart';
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
}
