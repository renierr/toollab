import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'news_page.dart';
import 'news_state.dart';
import 'news_sync_delegate.dart';

class NewsTool {
  NewsTool._();

  static ToolModel get config => ToolModel(
    id: 'news',
    name: 'News',
    description:
        'A timeline news reader with curated feeds and configurable sources',
    icon: Icons.newspaper_outlined,
    route: '/news',
    accentColor: AppTheme.accentAmber,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameNews,
    descriptionL10n: (l10n) => l10n.toolDescNews,
    androidProcessIsolated: true,
    createPage: (_) => const NewsPage(),
    syncDelegateFactory: NewsSyncDelegate.new,
    onClose: (context) => context.read<NewsState>().reduceCache(),
    stateProviders: () => [
      ChangeNotifierProvider<NewsState>(create: (_) => NewsState()),
    ],
  );
}
