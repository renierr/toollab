import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tool_lab/tools/trimz/models/trimz_saved_series.dart';
import 'package:tool_lab/tools/trimz/trimz_api.dart';

Map<String, dynamic> _card(String id, {String? localized}) => {
  'project_id': id,
  'slug': 'slug-$id',
  'title': 'Title $id',
  'localized_title': localized,
  'summary': 'Summary',
  'poster_16_9_url': 'https://cdn.example/$id.jpg',
  'owner_display_name': 'Owner',
  'episode_count': 12,
  'total_views': 3400,
  'card_badges': [
    {'kind': 'new_episodes', 'text': 'New Episodes'},
  ],
};

void main() {
  late List<Uri> requests;

  TrimzApi apiAnswering(Map<String, Object?> Function(Uri uri) body) {
    requests = [];
    return TrimzApi(
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes(
          utf8.encode(jsonEncode(body(request.url))),
          200,
        );
      }),
    );
  }

  test(
    'explore keeps sections with items and reads rails and paging',
    () async {
      final api = apiAnswering(
        (_) => {
          'sections': [
            {
              'id': 'trending',
              'title': 'Top 10 Today',
              'sectionType': 'ranked_carousel',
              'items': [_card('a', localized: 'Titel a')],
            },
            {
              'id': 'latest',
              'title': 'Latest',
              'sectionType': 'infinite_scroll',
              'items': [_card('b')],
              'hasMore': true,
              'nextOffset': 30,
            },
            {'id': 'empty', 'sectionType': 'grid', 'items': <Object>[]},
          ],
        },
      );

      final explore = await api.explore(locale: 'de', genre: 'horror');

      expect(requests.single.path, '/api/ms/explore-feed');
      expect(requests.single.queryParameters['genre'], 'horror');
      expect(requests.single.queryParameters['locale'], 'de');
      expect(explore.sections.map((s) => s.id), ['trending', 'latest']);
      final trending = explore.sections.first;
      expect(trending.rail && trending.ranked, isTrue);
      expect(trending.items.single.title, 'Titel a');
      expect(trending.items.single.badge, 'New Episodes');
      expect(trending.hasMore, isFalse);
      expect(explore.sections.last.rail, isFalse);
      expect(explore.sections.last.nextOffset, 30);
    },
  );

  test('series sorts episodes and drops ones without a video', () async {
    final api = apiAnswering(
      (_) => {
        'projectId': 'p1',
        'slug': 'slug-p1',
        'title': 'Show',
        'totalViews': 10,
        'videos': [
          {
            'shotId': 's2',
            'order': 1,
            'url': 'https://cdn.example/2.mp4',
            'durationSec': 60.5,
          },
          {
            'shotId': 's1',
            'order': 0,
            'url': 'https://cdn.example/1.mp4',
            'muxPlaybackUrl': 'https://stream.example/1.m3u8',
            'durationSec': 57.48,
            'sensitive': {'level': 'partial_nudity'},
          },
          {'shotId': 'locked', 'order': 2},
        ],
      },
    );

    final detail = await api.series('slug-p1', locale: 'en');

    expect(requests.single.path, '/api/ms/series/by-slug/slug-p1');
    expect(detail.episodes.map((e) => e.id), ['s1', 's2']);
    final first = detail.episodes.first;
    expect(first.sensitive, isTrue);
    expect(first.source(adaptive: true).path, '/1.m3u8');
    expect(first.source(adaptive: false).path, '/1.mp4');
    expect(detail.episodes.last.source(adaptive: true).path, '/2.mp4');
    expect(detail.runtime, const Duration(milliseconds: 117980));
  });

  test('a failed request throws a TrimzException with its status', () async {
    final api = TrimzApi(
      client: MockClient((_) async => http.Response('{"detail":"x"}', 404)),
    );
    await expectLater(
      api.genres(locale: 'en'),
      throwsA(isA<TrimzException>().having((e) => e.status, 'status', 404)),
    );
  });

  group('saved series', () {
    const saved = TrimzSavedSeries(
      id: 'p',
      slug: 'p',
      title: 'P',
      episodeCount: 5,
      episodeIndex: 2,
      positionMs: 20000,
      durationMs: 60000,
      watchedAt: 1,
    );

    test('continues in an unfinished episode at its position', () {
      expect(saved.nextIndex(5), 2);
      expect(saved.resumeAt(2), const Duration(seconds: 20));
      expect(saved.resumeAt(1), isNull);
    });

    test('moves past a finished episode, but not past the last', () {
      final finished = saved.copyWith(positionMs: 59000);
      expect(finished.nextIndex(5), 3);
      expect(finished.resumeAt(2), isNull);
      expect(finished.copyWith(episodeIndex: 4).nextIndex(5), 4);
    });

    test('counts earlier episodes and a finished current one as watched', () {
      expect(saved.watchedEpisode(1), isTrue);
      expect(saved.watchedEpisode(2), isFalse);
      final finished = saved.copyWith(positionMs: 60000);
      expect(finished.watchedEpisode(2), isTrue);
      expect(finished.watchedEpisode(3), isFalse);
      expect(finished.copyWith(episodeIndex: 4).watchedAll(5), isTrue);
      expect(saved.copyWith(watchedAt: () => null).watchedEpisode(0), isFalse);
    });
  });
}
