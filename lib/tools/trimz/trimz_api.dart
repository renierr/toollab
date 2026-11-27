import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import 'models/trimz_catalog.dart';
import 'models/trimz_series.dart';
import 'models/trimz_series_detail.dart';

class TrimzException implements Exception {
  final int? status;

  const TrimzException([this.status]);

  @override
  String toString() => 'TrimzException(${status ?? 'unreachable'})';
}

class TrimzExplore {
  final List<TrimzSection> sections;

  const TrimzExplore(this.sections);
}

/// The public, unauthenticated catalog API the trimz.tv web app uses.
class TrimzApi {
  static const String _host = 'api.trimz.tv';
  static const String _base = '/api/ms';
  static const Duration _timeout = Duration(seconds: 20);

  // Without it the feed leaves out the grid and genre sections.
  static const String _layouts =
      'carousel,ranked_carousel,infinite_scroll,grid,genre_rail,'
      'multi_experiment,localized_title_line,card_counts,card_stats';

  final http.Client? _client;

  const TrimzApi({this._client});

  Future<List<TrimzGenre>> genres({required String locale}) async {
    final json = await _get('/explore-genres', {'locale': locale});
    final genres = json['genres'];
    return [
      if (genres is List)
        for (final g in genres.whereType<Map<String, dynamic>>())
          ?TrimzGenre.tryParse(g),
    ];
  }

  Future<TrimzExplore> explore({required String locale, String? genre}) async {
    final json = await _get('/explore-feed', {
      'locale': locale,
      'genre': ?genre,
      'client_layouts': _layouts,
    });
    final sections = json['sections'];
    return TrimzExplore(
      [
        if (sections is List)
          for (final s in sections.whereType<Map<String, dynamic>>())
            TrimzSection.fromJson(s),
      ]..removeWhere((s) => s.items.isEmpty),
    );
  }

  Future<TrimzPage> moreOf(
    String sectionId, {
    required int offset,
    required String locale,
    String? genre,
  }) async {
    final json = await _get('/explore-feed/paginate', {
      'section_id': sectionId,
      'offset': '$offset',
      'limit': '30',
      'locale': locale,
      'genre': ?genre,
      'client_layouts': _layouts,
    });
    return TrimzPage(
      _series(json['items']),
      json['hasMore'] == true ? (json['nextOffset'] as num?)?.toInt() : null,
    );
  }

  Future<TrimzPage> search(
    String query, {
    required int offset,
    required String locale,
  }) async {
    final json = await _get('/search', {
      'q': query,
      'limit': '30',
      if (offset > 0) 'offset': '$offset',
      'locale': locale,
      'client_layouts': _layouts,
    });
    return TrimzPage(
      _series(json['items']),
      json['hasMore'] == true ? (json['nextOffset'] as num?)?.toInt() : null,
    );
  }

  Future<TrimzSeriesDetail> series(
    String slug, {
    required String locale,
  }) async => TrimzSeriesDetail.fromJson(
    await _get('/series/by-slug/${Uri.encodeComponent(slug)}', {
      'locale': locale,
    }),
  );

  List<TrimzSeries> _series(Object? items) => [
    if (items is List)
      for (final item in items.whereType<Map<String, dynamic>>())
        if (item['project_id'] is String) TrimzSeries.fromJson(item),
  ];

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(_host, '$_base$path', query);
    final http.Response response;
    try {
      final client = _client ?? await AppHttpClient.client;
      response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
    } catch (e) {
      debugLog('[TrimzApi] $path unreachable: $e');
      throw const TrimzException();
    }
    if (response.statusCode != 200) {
      debugLog('[TrimzApi] $path returned ${response.statusCode}');
      throw TrimzException(response.statusCode);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      debugLog('[TrimzApi] $path sent unreadable JSON: $e');
      throw TrimzException(response.statusCode);
    }
  }
}
