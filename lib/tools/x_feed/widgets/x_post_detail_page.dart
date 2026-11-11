import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_post.dart';
import '../x_feed_state.dart';
import '../x_timeline_controller.dart';
import 'x_back_key.dart';
import 'x_post_menu.dart';
import 'x_timeline_view.dart';

/// The thread around a post: its parents, the post itself and the replies.
class XPostDetailPage extends StatefulWidget {
  final XPost post;

  const XPostDetailPage({super.key, required this.post});

  @override
  State<XPostDetailPage> createState() => _XPostDetailPageState();
}

class _XPostDetailPageState extends State<XPostDetailPage> with DisposeCleanup {
  late final XTimelineController _thread;

  @override
  void initState() {
    super.initState();
    final state = context.read<XFeedState>();
    _thread = state.timeline(
      (cursor) => state.api.postDetail(widget.post.id, cursor: cursor),
    );
    onDispose(_thread.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return XBackKey(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.xFeedPostTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.xFeedRefresh,
              onPressed: _thread.refresh,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.xFeedMoreActions,
              onPressed: () => XPostMenu.show(context, widget.post),
            ),
          ],
        ),
        body: XTimelineView(controller: _thread, focalPostId: widget.post.id),
      ),
    );
  }
}
