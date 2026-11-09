import 'package:tool_lab/l10n/app_localizations.dart';

import 'news_catalog.dart';
import 'news_error.dart';

/// Null when [url] is a usable http(s) feed URL.
String? newsFeedUrlError(AppLocalizations l10n, String url) {
  if (url.isEmpty) return l10n.newsSourceRequired;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      (!uri.isScheme('http') && !uri.isScheme('https')) ||
      uri.host.isEmpty) {
    return l10n.newsSourceInvalidUrl;
  }
  return null;
}

String newsErrorText(AppLocalizations l10n, Object error) {
  final code = error is NewsException ? error.code : '$error';
  final separator = code.indexOf(':');
  final name = separator < 0 ? code : code.substring(0, separator);
  final kind = NewsError.values.where((e) => e.name == name).firstOrNull;
  return switch (kind) {
    NewsError.invalidUrl => l10n.newsErrorInvalidUrl,
    NewsError.unreachable => l10n.newsErrorUnreachable,
    NewsError.httpStatus => l10n.newsErrorHttpStatus(
      code.substring(separator + 1),
    ),
    NewsError.tooLarge => l10n.newsErrorTooLarge,
    NewsError.invalidXml => l10n.newsErrorInvalidXml,
    NewsError.notAFeed => l10n.newsErrorNotAFeed,
    NewsError.noEntries => l10n.newsErrorNoEntries,
    NewsError.notHtml => l10n.newsErrorNotHtml,
    NewsError.noArticleBody => l10n.newsErrorNoArticleBody,
    // Errors stored before codes existed are plain English text.
    null => code,
  };
}

String newsCategoryLabel(AppLocalizations l10n, String id) {
  return switch (id) {
    'top' => l10n.newsCategoryTop,
    'world' => l10n.newsCategoryWorld,
    'germany' => l10n.newsCategoryGermany,
    'technology' => l10n.newsCategoryTechnology,
    'business' => l10n.newsCategoryBusiness,
    'science' => l10n.newsCategoryScience,
    'sport' => l10n.newsCategorySport,
    'culture' => l10n.newsCategoryCulture,
    NewsCatalog.customCategory => l10n.newsCategoryCustom,
    _ => l10n.newsCategoryCustom,
  };
}
