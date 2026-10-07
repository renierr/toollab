import 'package:tool_lab/l10n/app_localizations.dart';

import 'models/paperless_filter.dart';

String paperlessSortLabel(AppLocalizations l10n, PaperlessSort sort) =>
    switch (sort) {
      PaperlessSort.addedNewest => l10n.paperlessSortAddedNewest,
      PaperlessSort.addedOldest => l10n.paperlessSortAddedOldest,
      PaperlessSort.createdNewest => l10n.paperlessSortCreatedNewest,
      PaperlessSort.createdOldest => l10n.paperlessSortCreatedOldest,
      PaperlessSort.modifiedNewest => l10n.paperlessSortModifiedNewest,
      PaperlessSort.titleAz => l10n.paperlessSortTitle,
    };
