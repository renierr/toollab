import 'package:tool_lab/l10n/app_localizations.dart';

import 'news_catalog.dart';

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
