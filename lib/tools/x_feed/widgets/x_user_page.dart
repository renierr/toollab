import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../api/x_api.dart';
import '../models/x_user.dart';
import '../x_feed_state.dart';
import '../x_media_actions.dart';
import '../x_timeline_controller.dart';
import 'x_back_key.dart';
import 'x_error_view.dart';
import 'x_timeline_view.dart';
import 'x_user_header.dart';

class XUserPage extends StatefulWidget {
  final String screenName;

  const XUserPage({super.key, required this.screenName});

  @override
  State<XUserPage> createState() => _XUserPageState();
}

class _XUserPageState extends State<XUserPage> with DisposeCleanup {
  XUser? _user;
  XApiException? _error;
  bool _mediaOnly = false;
  XTimelineController? _posts;
  XTimelineController? _media;

  @override
  void initState() {
    super.initState();
    onDispose(() {
      _posts?.dispose();
      _media?.dispose();
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final user = await context.read<XFeedState>().api.user(widget.screenName);
      if (!mounted) return;
      setState(() {
        _user = user;
        if (user == null) {
          _error = const XApiException(XApiErrorKind.server, 'User not found');
        }
      });
    } on XApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  XTimelineController _controller(XUser user) {
    final state = context.read<XFeedState>();
    if (_mediaOnly) {
      return _media ??= state.timeline(
        (cursor) =>
            state.api.userPosts(user.id, mediaOnly: true, cursor: cursor),
      );
    }
    return _posts ??= state.timeline(
      (cursor) => state.api.userPosts(user.id, cursor: cursor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = _user;
    final error = _error;

    final Widget body;
    if (user != null) {
      body = XTimelineView(
        key: ValueKey(_mediaOnly),
        controller: _controller(user),
        header: XUserHeader(
          user: user,
          mediaOnly: _mediaOnly,
          onMediaOnlyChanged: (value) => setState(() => _mediaOnly = value),
        ),
      );
    } else if (error != null) {
      body = Center(
        child: XErrorView(error: error, onRetry: _load),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return XBackKey(
      child: Scaffold(
        appBar: AppBar(
          title: Text('@${widget.screenName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: l10n.xFeedOpenInBrowser,
              onPressed: () => XMediaActions.openUrl(
                context,
                Uri.parse('https://x.com/${widget.screenName}'),
              ),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}
