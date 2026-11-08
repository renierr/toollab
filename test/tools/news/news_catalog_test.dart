import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/news/news_catalog.dart';

void main() {
  test('optional feeds are available in the catalog but not seeded', () {
    final expected = {
      'ComputerBase': 'technology',
      'Golem.de': 'technology',
      'SmartDroid': 'technology',
      'mobiFlip': 'technology',
      'Hackaday': 'technology',
      'scinexx': 'science',
      'LangweileDich.net': 'culture',
      'Atlas Obscura': 'culture',
      'xkcd': 'culture',
    };
    final seededUrls = NewsCatalog.seeds
        .map((source) => source.feedUrl)
        .toSet();
    for (final entry in expected.entries) {
      final sources = NewsCatalog.byCategory[entry.value]!;
      final source = sources.singleWhere((source) => source.title == entry.key);
      expect(NewsCatalog.categoryForFeed(source.feedUrl), entry.value);
      expect(seededUrls, isNot(contains(source.feedUrl)));
      expect(Uri.parse(source.feedUrl).scheme, 'https');
    }
  });
}
