import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';
import 'x_session.dart';
import 'x_transaction_id.dart';

class XOperation {
  final String queryId;
  final String name;
  final List<String> features;
  final List<String> fieldToggles;

  const XOperation({
    required this.queryId,
    required this.name,
    required this.features,
    required this.fieldToggles,
  });

  factory XOperation.fromJson(Map<String, dynamic> json) => XOperation(
    queryId: json['queryId'] as String,
    name: json['name'] as String,
    features: (json['features'] as List).cast<String>(),
    fieldToggles: (json['fieldToggles'] as List).cast<String>(),
  );

  Map<String, Object> toJson() => {
    'queryId': queryId,
    'name': name,
    'features': features,
    'fieldToggles': fieldToggles,
  };
}

/// What X's private API needs and changes without notice: GraphQL query ids,
/// the feature flags each query must send, and the transaction-id key. All of
/// it is read from x.com's own page and scripts, so a rotation heals itself
/// on the next refresh instead of needing an app update.
class XWebConfig {
  final Map<String, XOperation> operations;
  final Map<String, bool> featureValues;
  final XTransactionId? transaction;
  final DateTime fetchedAt;

  const XWebConfig({
    required this.operations,
    required this.featureValues,
    required this.transaction,
    required this.fetchedAt,
  });

  static const Duration maxAge = Duration(hours: 6);
  static const String _settingKey = 'web_config';

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36';

  static const Set<String> requiredOperations = {
    'HomeTimeline',
    'HomeLatestTimeline',
    'TweetDetail',
    'TweetResultByRestId',
    'UserByScreenName',
    'UserTweets',
    'UserMedia',
    'SearchTimeline',
    'Bookmarks',
    'FavoriteTweet',
    'UnfavoriteTweet',
    'CreateRetweet',
    'DeleteRetweet',
    'CreateBookmark',
    'DeleteBookmark',
  };

  bool get isStale => DateTime.now().difference(fetchedAt) > maxAge;

  Map<String, bool> featuresFor(XOperation op) => {
    for (final name in op.features) name: featureValues[name] ?? true,
  };

  static Future<XWebConfig?> loadCached() async {
    try {
      final raw = await DatabaseService.instance.getSetting(
        XFeedTool.config.id,
        _settingKey,
      );
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return XWebConfig(
        operations: {
          for (final op in (json['operations'] as List).map(
            (e) => XOperation.fromJson(e as Map<String, dynamic>),
          ))
            op.name: op,
        },
        featureValues: (json['features'] as Map).cast<String, bool>(),
        transaction: XTransactionId.fromJson(json['transaction']),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          json['fetchedAt'] as int,
        ),
      );
    } catch (e) {
      errorLog('[XWebConfig] Cached config unreadable: $e');
      return null;
    }
  }

  Future<void> _save() => DatabaseService.instance.setSetting(
    XFeedTool.config.id,
    _settingKey,
    jsonEncode({
      'operations': [for (final op in operations.values) op.toJson()],
      'features': featureValues,
      'transaction': transaction?.toJson(),
      'fetchedAt': fetchedAt.millisecondsSinceEpoch,
    }),
  );

  static Future<void> clearCache() =>
      DatabaseService.instance.setSetting(XFeedTool.config.id, _settingKey, '');

  static final RegExp _scriptPattern = RegExp(
    r'https://abs\.twimg\.com/responsive-web/client-web[\w-]*/[\w.~-]+\.js',
  );
  static final RegExp _operationPattern = RegExp(
    r'queryId:\s*"([^"]+)",\s*operationName:\s*"([^"]+)",\s*operationType:\s*"[^"]+",\s*metadata:\s*\{\s*featureSwitches:\s*\[([^\]]*)\],\s*fieldToggles:\s*\[([^\]]*)\]',
  );
  static final RegExp _quoted = RegExp(r'"([^"]+)"');

  /// Scans the home page's scripts, main bundle first, until every operation
  /// the tool uses is known or the scripts run out.
  static Future<XWebConfig> fetch(http.Client client, XSession session) async {
    final headers = {
      'User-Agent': userAgent,
      'Cookie': session.cookieHeader,
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    final home = await client.get(
      Uri.parse('https://x.com/home'),
      headers: headers,
    );
    if (home.statusCode != 200) {
      throw http.ClientException('x.com/home answered ${home.statusCode}');
    }
    final html = home.body;

    final scripts = scriptCandidates(html);
    if (scripts.isEmpty) {
      throw const FormatException('No web client scripts on x.com/home');
    }

    final operations = <String, XOperation>{};
    var scanned = 0;
    for (final url in scripts) {
      if (requiredOperations.every(operations.containsKey) ||
          scanned >= _maxScannedScripts) {
        break;
      }
      scanned++;
      try {
        final res = await client.get(Uri.parse(url), headers: headers);
        if (res.statusCode != 200) continue;
        for (final m in _operationPattern.allMatches(res.body)) {
          operations.putIfAbsent(
            m.group(2)!,
            () => XOperation(
              queryId: m.group(1)!,
              name: m.group(2)!,
              features: _names(m.group(3)!),
              fieldToggles: _names(m.group(4)!),
            ),
          );
        }
      } catch (e) {
        debugLog('[XWebConfig] Script $url failed: $e');
      }
    }
    if (operations.isEmpty) {
      throw const FormatException('No GraphQL operations found on x.com');
    }
    final missing = requiredOperations.difference(operations.keys.toSet());
    if (missing.isNotEmpty) {
      debugLog('[XWebConfig] Operations not found: $missing');
    }

    final featureValues = <String, bool>{};
    for (final name in {for (final op in operations.values) ...op.features}) {
      final matches = RegExp(
        '"${RegExp.escape(name)}":\\{"value":(true|false)',
      ).allMatches(html);
      // The user's config follows the defaults in the page state.
      if (matches.isNotEmpty) {
        featureValues[name] = matches.last.group(1) == 'true';
      }
    }

    XTransactionId? transaction;
    final onDemand = XTransactionId.onDemandUrl(html);
    if (onDemand != null) {
      try {
        final res = await client.get(onDemand, headers: headers);
        if (res.statusCode == 200) {
          transaction = XTransactionId.create(html, res.body);
        }
      } catch (e) {
        debugLog('[XWebConfig] ondemand chunk failed: $e');
      }
    }
    if (transaction == null) {
      debugLog('[XWebConfig] No transaction id key; requests go unsigned');
    }

    final config = XWebConfig(
      operations: operations,
      featureValues: featureValues,
      transaction: transaction,
      fetchedAt: DateTime.now(),
    );
    await config._save();
    return config;
  }

  static List<String> _names(String list) =>
      _quoted.allMatches(list).map((m) => m.group(1)!).toList();

  static const int _maxScannedScripts = 25;

  /// Chunk names whose bundles hold the queries this tool uses; `main` holds
  /// most of them, the home and bookmark timelines load lazily.
  static const Map<String, int> _chunkKeywords = {
    'bundle.HomeTimeline': 4,
    'bundle.Bookmarks': 4,
    'LoggedInMain': 1,
    'Conversation': 1,
    'UserProfile': 1,
    'Search': 1,
  };

  // webpack's runtime: ({id:"name",…})[e]||e)+"."+({id:"hash",…})[e]+"a.js"
  static final RegExp _chunkMapPattern = RegExp(
    r'\(\{([^{}]*)\}\)\[(\w+)\]\|\|\2\)\+"\."\+\(\{([^{}]*)\}\)\[\2\]\+"a\.js"',
  );
  static final RegExp _chunkEntry = RegExp(r'(\d+):"([^"]+)"');

  /// Scripts to scan for operations, most promising first: the scripts the
  /// page names (main bundle ahead), then lazy chunks whose names match
  /// [_chunkKeywords].
  @visibleForTesting
  static List<String> scriptCandidates(String html) {
    final named = _scriptPattern
        .allMatches(html)
        .map((m) => m.group(0)!)
        .where(
          (url) =>
              !url.contains('/i18n/') &&
              !url.contains('/vendor.') &&
              !url.contains('ondemand.s'),
        )
        .toSet()
        .toList();
    final main = named.where((url) => url.contains('/main.')).firstOrNull;
    named.sort((a, b) => (a == main ? 0 : 1).compareTo(b == main ? 0 : 1));
    if (main == null) return named;

    final map = _chunkMapPattern.firstMatch(html);
    if (map == null) return named;
    final base = main.substring(0, main.lastIndexOf('/') + 1);
    final names = {
      for (final m in _chunkEntry.allMatches(map.group(1)!))
        m.group(1)!: m.group(2)!,
    };
    final scored = <(int, String)>[];
    for (final m in _chunkEntry.allMatches(map.group(3)!)) {
      final name = names[m.group(1)!];
      if (name == null) continue;
      var score = 0;
      _chunkKeywords.forEach((keyword, weight) {
        if (name.contains(keyword)) score += weight;
      });
      if (score > 0) scored.add((score, '$base$name.${m.group(2)!}a.js'));
    }
    // Shorter names share fewer bundles, so they are the likelier home.
    scored.sort(
      (a, b) => a.$1 != b.$1
          ? b.$1.compareTo(a.$1)
          : a.$2.length.compareTo(b.$2.length),
    );
    return [...named, ...scored.map((s) => s.$2)];
  }
}
