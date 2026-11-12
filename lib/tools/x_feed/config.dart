import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'x_feed_page.dart';
import 'x_feed_state.dart';

class XFeedTool {
  XFeedTool._();

  static ToolModel get config => ToolModel(
    id: 'x-feed',
    name: 'X Feed',
    description:
        'Your X timeline without ads, with native video playback and sharing',
    icon: Icons.dynamic_feed_outlined,
    route: '/x-feed',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameXFeed,
    descriptionL10n: (l10n) => l10n.toolDescXFeed,
    androidProcessIsolated: true,
    createPage: (_) => const XFeedPage(),
    onClose: (context) => unawaited(context.read<XFeedState>().release()),
    stateProviders: () => [
      ChangeNotifierProvider<XFeedState>(create: (_) => XFeedState()),
    ],
  );
}
